# frozen_string_literal: true

# A sent order opened by its token to be shown: to its owner, or to whoever the owner shared the link with, as
# OrderPolicy lets them. A status older than the configured minutes is asked of the provider first, once in those
# minutes whoever opens the link and whatever the provider answers; when it does not answer, the kept status is shown.
module Orders::Bookings::Open
  # Nil for a token of a cart, which the cart shows.
  def self.owned(owner)
    order = Order.where.not(state: 'cart').find_by(token: owner.token)
    return unless order
    raise Orders::Carts::Refused.new(:cart_not_found, status: :not_found) unless OrderPolicy.new(owner, order).show?

    fresh(order)
  end

  def self.fresh(order, config: Orders::Bookings.config)
    if Orders::Bookings::RefreshStatus.stale?(order, config:) &&
       Orders::Bookings::Lease.take("status:#{order.token}", config.status_stale_minutes.minutes.to_i)
      Orders::Bookings::RefreshStatus.call(order)
    end
    order
  end
end
