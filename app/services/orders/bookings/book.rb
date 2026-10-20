# frozen_string_literal: true

# Books the cart of the one who asks: checks its prices and stock live, takes the client's data and consent, and sends
# it to its provider as a pick-up order with our own number, once and without repeating. An order whose sending failed
# is tried again the same way, but first looked for at the provider so a second order is never made. Returns the order
# and whether the provider took it.
class Orders::Bookings::Book
  Result = Data.define(:order, :submitted)

  def self.call(owner, request) = new(owner, request).call

  def initialize(owner, request)
    @owner = owner
    @request = request
  end

  def call
    order = bookable
    offer = confirmed(order)
    take_client(order)
    sent = order.own_number && sent_before(order)
    return accepted(order, offer, sent) if sent

    Orders::Bookings::PriceCheck.call(order, offer, @request)
    Orders::OwnNumbers::Assign.call(order)
    order.save!
    send_to_provider(order, offer)
  end

  private

  def bookable
    order = Orders::Bookings::Find.call(@owner)
    unless Orders::Bookings.config.allowed?(order.drugstore_id)
      refuse(:booking_not_allowed_in_drugstore, :unprocessable_content)
    end
    refuse(:cart_changed, :conflict) unless @request.matches?(order.items)

    order
  end

  def confirmed(order)
    case (offer = live_offer(order))
    when Orders::Offers::DrugstoreOffer then offer.known? ? offer : unavailable
    when Orders::Offers::Failure then offer.rate_limited? ? busy(offer.retry_after) : unavailable
    else unavailable
    end
  end

  # A disabled provider keeps its carts but takes no orders until it comes back.
  def live_offer(order)
    provider = order.provider
    unavailable unless provider.active?
    adapter = Orders::Offers::Adapters.for(provider, user_id: @owner.user_id)
    adapter&.in_drugstore(order.drugstore, order.items.includes(:goods).to_a, share: nil)
  end

  # The moment of the first consent stays: an order made from that attempt is looked for since then.
  def take_client(order)
    customer = @request.customer
    order.assign_attributes(
      customer_first_name: customer['first_name'],
      customer_last_name: customer['last_name'],
      customer_middle_name: customer['middle_name'],
      customer_phone_number: customer['phone_number'],
      customer_email: customer['email'],
      register_account: @request.register_account,
      provider_drugstore_external_id: order.drugstore.provider_ref(order.provider)
    )
    order.personal_data_consent_at ||= Time.current
  end

  def sent_before(order)
    found = adapter(order).find_submitted(order, since: order.personal_data_consent_at)
    return found unless found.is_a?(Orders::Bookings::Failure)

    found.rate_limited? ? busy(found.retry_after) : unavailable
  end

  def send_to_provider(order, offer)
    Orders::Bookings::Snapshot.call(order, offer)
    answer = adapter(order).submit(order)
    return accepted(order, offer, answer) if answer.is_a?(Pharmapoint::PartnerOrder)

    order.state = 'submission_failed'
    keep(order)
    Result.new(order:, submitted: false)
  end

  def accepted(order, offer, partner_order)
    Orders::Bookings::Snapshot.call(order, offer)
    order.assign_attributes(state: 'submitted', **partner_state(partner_order))
    keep(order)
    Result.new(order:, submitted: true)
  end

  def partner_state(partner_order)
    {
      provider_order_number: partner_order.number,
      status_name: partner_order.status_name,
      status_comment: partner_order.status_comment,
      cancel_reason: partner_order.cancel_reason,
      progress: partner_order.progress,
      provider_payload: partner_order.record,
      provider_updated_at: partner_order.updated_at,
      status_synced_at: Time.current
    }
  end

  # The order leaves the cart first, so its items are saved as the snapshot of a sent order.
  def keep(order)
    order.save!
    order.items.each(&:save!)
  end

  def adapter(order) = Orders::Bookings::Adapters.for(order.provider, user_id: @owner.user_id) || unavailable

  def busy(retry_after)
    raise Orders::Carts::Refused.new(:booking_check_busy, status: :service_unavailable, retry_after:)
  end

  def unavailable = refuse(:booking_check_unavailable, :service_unavailable)

  def refuse(code, status) = raise(Orders::Carts::Refused.new(code, status:))
end
