# frozen_string_literal: true

# Holds a booking back when the live prices and stock of the drugstore are worse than what the user agreed to: a higher
# price or a missing item asks for a new consent, with the items as they are now. A lower price is taken as it is.
class Orders::Bookings::PriceCheck
  def self.call(order, offer, request) = new(order, offer, request).call

  def initialize(order, offer, request)
    @order = order
    @offer = offer
    @request = request
  end

  def call
    changed = @order.items.reject { agreed?(it) }
    return if changed.empty?

    items = changed.map { |item| current(item) }
    raise Orders::Carts::Refused.new(:booking_prices_changed, status: :conflict, details: { items: })
  end

  private

  def agreed?(item)
    goods_id = item.goods_id
    return false unless goods_id

    line = @offer.line_for(goods_id)
    price = line&.price
    agreed = @request.goods[goods_id]&.price
    return false unless price && agreed

    available?(line, item) && price <= agreed
  end

  def available?(line, item) = (line&.fulfilled && line.available_quantity >= item.quantity) || false

  def current(item)
    goods_id = item.goods_id
    line = goods_id && @offer.line_for(goods_id)
    price = line&.price
    {
      goods_id:,
      quantity: item.quantity.to_i,
      available: available?(line, item),
      available_quantity: line&.available_quantity,
      price: price && ActiveSupport::NumberHelper.number_to_rounded(price, precision: 2)
    }
  end
end
