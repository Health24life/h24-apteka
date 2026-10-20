# frozen_string_literal: true

# Who asks for a cart: a signed-in user, a guest with the token of their cart, or both right after signing in.
class Orders::Carts::Owner < Data.define(:user_id, :token); end
