# frozen_string_literal: true

# The cart of the API: who owns it, what of it is still good, its live prices, and the changes a user makes to it.
module Orders::Carts
  class << self
    # The settings of the cart, built from the environment at boot by config/initializers/settings.rb.
    attr_accessor :config

    # What the drugstore of the cart has of its items, as they are in memory. A disabled provider is not asked: its
    # carts stay, without prices, until it comes back.
    def offer(cart, user_id)
      provider = cart.provider
      return unless provider.active?

      Orders::Offers::Adapters.for(provider, user_id:)&.in_drugstore(cart.drugstore, cart.items.to_a)
    end
  end
end
