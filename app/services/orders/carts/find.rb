# frozen_string_literal: true

# The cart of the one who asks. A guest's cart is found by its secret token; an account's by the user. With both, right
# after signing in, the guest's cart goes to the account only when the account has none: carts are never merged, and
# the guest's one is left to live out its days.
class Orders::Carts::Find
  def self.call(owner) = new(owner).call

  def initialize(owner)
    @owner = owner
  end

  def call
    guest = guest_cart
    user_id = @owner.user_id
    return guest unless user_id

    account = Order.cart.find_by(user_id:)
    return account if account

    claim(guest, user_id) if guest
  end

  private

  # A token of a cart that went to an account, or of an order already sent, finds nothing.
  def guest_cart
    token = @owner.token
    Order.cart.find_by(token:, user_id: nil) if token
  end

  # Two requests may claim at once; the unique cart of a user lets one through, and the other takes its cart.
  def claim(cart, user_id)
    cart.update!(user_id:)
    cart
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    Order.cart.find_by(user_id:)
  end
end
