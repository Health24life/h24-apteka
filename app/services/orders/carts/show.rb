# frozen_string_literal: true

# The cart of the one who asks, with what became unusable taken out and the live prices of its drugstore. A provider
# that does not answer leaves the cart shown without prices rather than an error.
class Orders::Carts::Show
  def self.call(owner) = new(owner).call

  def self.offer(cart, user_id)
    adapter = Orders::Offers::Adapters.for(cart.provider, user_id:)
    adapter&.in_drugstore(cart.drugstore, cart.items.includes(:goods).to_a)
  end

  def initialize(owner)
    @owner = owner
  end

  def call
    opened = Orders::Carts::Opening.call(@owner)
    cart = opened.cart
    Orders::Carts::View.of(cart, self.class.offer(cart, @owner.user_id), removed: opened.removed)
  end
end
