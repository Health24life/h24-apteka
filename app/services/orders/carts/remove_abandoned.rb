# frozen_string_literal: true

# Removes the guest carts nobody changed for longer than the configured days, with their items. An account's cart has
# no end, and a sent order is never removed. Returns how many carts went.
class Orders::Carts::RemoveAbandoned
  def self.call(config: Orders::Carts.config, now: Time.current) = new(config, now).call

  def initialize(config, now)
    @config = config
    @now = now
  end

  def call
    count = 0
    Order.cart.where(user_id: nil).where(updated_at: ...(@now - @config.guest_ttl_days.days)).find_each do |cart|
      cart.destroy!
      count += 1
    end
    count
  end
end
