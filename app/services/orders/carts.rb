# frozen_string_literal: true

# The cart of the API: who owns it, what of it is still good, its live prices, and the changes a user makes to it.
module Orders::Carts
  class << self
    # The settings of the cart, built from the environment at boot by config/initializers/settings.rb.
    attr_accessor :config
  end
end
