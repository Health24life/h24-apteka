# frozen_string_literal: true

# A cart opened for use, with what was taken out of it on the way.
class Orders::Carts::Opened < Data.define(:cart, :removed); end
