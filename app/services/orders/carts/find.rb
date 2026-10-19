# frozen_string_literal: true

# The cart of the one who asks. With a token, the cart of that token: a guest's cart opens to anyone with the token,
# an account's cart only with the session of its user. A signed-in user who opens a guest's cart takes it to the
# account when the account has none; carts are never merged. Without a token, the cart of the signed-in user.
class Orders::Carts::Find
  def self.call(owner) = new(owner).call

  def initialize(owner)
    @owner = owner
  end

  def call
    token = @owner.token
    return account_cart unless token

    cart = Order.cart.find_by(token:)
    cart && opened(cart)
  end

  private

  def account_cart
    user_id = @owner.user_id
    Order.cart.find_by(user_id:) if user_id
  end

  def opened(cart)
    user_id = @owner.user_id
    owner_id = cart.user_id
    return (cart if owner_id == user_id) if owner_id

    user_id && !Order.cart.exists?(user_id:) ? claim(cart, user_id) : cart
  end

  # Two requests may claim at once; the unique cart of a user lets one through, and the other keeps the guest's cart.
  def claim(cart, user_id)
    cart.update!(user_id:)
    cart
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    cart.reload
  end
end
