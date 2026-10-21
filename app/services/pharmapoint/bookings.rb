# frozen_string_literal: true

# Makes an order of the catalog at Pharmapoint and finds it there again. An order goes as a pick-up paid in the
# drugstore, with our own number, so the partner can tell its orders from the site's. A failure of the partner becomes
# an answer of its own; any other error is a bug and is raised. Nothing is repeated.
class Pharmapoint::Bookings
  # The ways of receiving and paying of Health24 in the codes of the partner, which uses more than one notation.
  DELIVERY_TYPE_CODES = { 'pick_up' => 'pick_up' }.freeze
  PAYMENT_METHOD_CODES = { 'cash_in_store' => 'cash_in_store' }.freeze
  # The partner's clock and ours may differ a little.
  CLOCK_SKEW = 1.minute

  attr_reader :provider

  def initialize(provider:, user_id: nil, config: Pharmapoint.config, rate_limiter: Pharmapoint::RateLimiter.new(config:))
    @provider = provider
    @client = Pharmapoint::Client.new(provider:, config:, purpose: :booking, user_id:, rate_limiter:)
  end

  def submit(order)
    @client.store_pick_up_order(body(order))
  rescue Pharmapoint::Error => e
    failure(e)
  end

  # The order the partner may have made from an earlier attempt that gave no answer, looked for by the phone that
  # attempt went with. The partner's history does not give our own number back, so an order of the client counts as
  # this one when it is in the same drugstore, was made no earlier than the first attempt, has the same goods in the
  # same quantities and is not already kept with another of our orders.
  def find_submitted(order, since:, phone:)
    found = @client.order_history(phone:).select { same?(it, order, since) }
    taken = taken_numbers(order, found.map(&:number))
    found.find { taken.exclude?(it.number) }
  rescue Pharmapoint::Error => e
    failure(e)
  end

  # The order as the partner keeps it now, read by the partner's number.
  def status(order)
    @client.order(order.provider_order_number.to_s)
  rescue Pharmapoint::Error => e
    failure(e)
  end

  def cancel(order, reason:)
    @client.cancel_order(number: order.provider_order_number.to_s, phone: order.customer_phone_number.to_s, reason:)
  rescue Pharmapoint::Error => e
    failure(e)
  end

  private

  def body(order)
    {
      drugstore_id: order.provider_drugstore_external_id,
      **customer(order),
      **receiving(order),
      goods: order.items.map { line(it) },
      online_drugstore_order_number: order.own_number,
      total: money(order.items.sum { it.total&.to_d || 0 })
    }
  end

  # Delivery is required even for a pick-up.
  def receiving(order)
    {
      delivery: { delivery_type_code: DELIVERY_TYPE_CODES.fetch(order.delivery&.delivery_type_code || 'pick_up') },
      payment: { payment_method_code: PAYMENT_METHOD_CODES.fetch(order.payment&.payment_type_code || 'cash_in_store') }
    }
  end

  def customer(order)
    {
      customer_first_name: order.customer_first_name,
      customer_last_name: order.customer_last_name,
      customer_middle_name: order.customer_middle_name,
      customer_phone_number: order.customer_phone_number,
      customer_email: order.customer_email
    }.compact
  end

  def line(item)
    { goods_id: item.provider_goods_external_id, quantity: packs(item), price: money(item.price&.to_d || 0) }
  end

  # The partner counts whole packs and the cart lets in only them: a part of a pack here is a bug, not a quantity.
  def packs(item)
    quantity = item.quantity
    raise ArgumentError, "item #{item.id} is a part of a pack: #{quantity.to_s('F')}" if quantity.frac.nonzero?

    quantity.to_i
  end

  # The partner takes amounts as strings with two places.
  def money(amount) = format('%.2f', amount)

  def same?(partner_order, order, since)
    created_at = partner_order.created_at
    return false unless created_at && since

    partner_order.drugstore_external_id == order.provider_drugstore_external_id &&
      created_at >= since - CLOCK_SKEW &&
      quantities(partner_order.lines.map { [ it.goods_external_id, it.quantity ] }) ==
        quantities(order.items.map { [ it.provider_goods_external_id.to_s, it.quantity ] })
  end

  def taken_numbers(order, numbers)
    return [] if numbers.empty?

    Order.where(provider: @provider, provider_order_number: numbers).where.not(id: order.id)
      .pluck(:provider_order_number)
  end

  def quantities(pairs) = pairs.group_by(&:first).transform_values { |same| same.sum { it.last.to_d } }

  def failure(error)
    case error
    when Pharmapoint::RateLimited then Orders::Bookings::Failure.new(
      reason: :rate_limited,
      retry_after: error.retry_after
    )
    when Pharmapoint::TransientError then Orders::Bookings::Failure.new(reason: :unavailable, retry_after: nil)
    else
      Rails.error.report(error, handled: true, context: { source: 'booking', provider: @provider.code })
      if error.is_a?(Pharmapoint::PermanentError)
        return Orders::Bookings::Failure.new(reason: :refused, retry_after: nil)
      end

      Orders::Bookings::Failure.new(reason: :unavailable, retry_after: nil)
    end
  end
end
