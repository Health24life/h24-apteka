# frozen_string_literal: true

# The order to book by its token: a cart, or an order whose sending failed and is tried again. One already with the
# provider is refused; a token of no such order, or one OrderPolicy keeps from the one who asks, finds nothing.
class Orders::Bookings::Find
  BOOKABLE = %w[cart submission_failed].freeze

  def self.call(owner)
    order = Order.find_by(token: owner.token)
    raise Orders::Carts::Refused.new(:cart_not_found, status: :not_found) unless order && OrderPolicy.new(
      owner,
      order
    ).open?
    raise Orders::Carts::Refused.new(:order_already_submitted, status: :conflict) unless BOOKABLE.include?(order.state)

    order.cart? ? Orders::Carts::Opening.tidy(order).cart : order
  end
end
