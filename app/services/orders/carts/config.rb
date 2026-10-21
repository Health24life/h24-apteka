# frozen_string_literal: true

# Settings of the cart. The values come from the environment in config/initializers/settings.rb, which keeps the frozen
# result as Orders::Carts.config.
class Orders::Carts::Config
  include Dry::Configurable

  # Days a guest's cart lives after its last change; an account's cart has no end.
  setting :guest_ttl_days, default: 7, constructor: ->(value) { Integer(value) }, reader: true
end
