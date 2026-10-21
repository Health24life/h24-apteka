# frozen_string_literal: true

# The cart of the one who asks, with what became unusable taken out and the live prices of its drugstore. A provider
# that does not answer leaves the cart shown without prices rather than an error.
class Orders::Carts::Show
  def self.call(owner) = new(owner).call

  def initialize(owner)
    @owner = owner
  end

  def call
    opened = Orders::Carts::Opening.call(@owner)
    cart = opened.cart
    Orders::Carts::View.of(cart, Orders::Carts.offer(cart, @owner.user_id), removed: opened.removed)
  end
end
