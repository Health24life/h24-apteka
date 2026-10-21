# frozen_string_literal: true

# A cart with what could no longer be in it taken out. `cart` is nil when the whole cart went, and `reason` tells why.
class Orders::Carts::Tidied < Data.define(:cart, :removed, :reason); end
