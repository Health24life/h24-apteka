# frozen_string_literal: true

# A SKU taken out of the cart because it can no longer be sold, and why.
class Orders::Carts::Removed < Data.define(:reason, :goods); end
