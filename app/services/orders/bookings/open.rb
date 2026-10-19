# frozen_string_literal: true

# A sent order opened to be shown: to its owner by its token, if OrderPolicy lets them, or to anyone by its shared
# link. A status older than the configured minutes is asked of the provider first; when it does not answer, the kept
# status is shown.
module Orders::Bookings::Open
  # Nil for a token of a cart, which the cart shows.
  def self.owned(owner)
    order = Order.where.not(state: 'cart').find_by(token: owner.token)
    return unless order
    raise Orders::Carts::Refused.new(:cart_not_found, status: :not_found) unless OrderPolicy.new(owner, order).open?

    fresh(order)
  end

  # A cart does not open by its link: only a sent order is shared, for someone else to pick it up.
  def self.shared(share_token)
    order = Order.where.not(state: 'cart').find_by(share_token:) ||
            raise(Orders::Carts::Refused.new(:order_not_found, status: :not_found))
    fresh(order)
  end

  def self.fresh(order)
    Orders::Bookings::RefreshStatus.call(order) if Orders::Bookings::RefreshStatus.stale?(order)
    order
  end
end
