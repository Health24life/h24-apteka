# frozen_string_literal: true

# Booking a cart: the cart sent to its provider as a pick-up order, checked live first, and retried without a double.
module Orders::Bookings
  class << self
    # The settings of booking, built from the environment at boot by config/initializers/settings.rb.
    attr_accessor :config
  end
end
