# frozen_string_literal: true

# Sets the quantity of an item of the cart of the one who asks, checked live against what the drugstore has.
class Orders::Carts::ChangeQuantity
  def self.call(owner, item_id:, quantity:) = new(owner, item_id, quantity).call

  def initialize(owner, item_id, quantity)
    @owner = owner
    @item_id = item_id.to_i
    @quantity = quantity
  end

  def call
    opened = Orders::Carts::Opening.call(@owner)
    cart = opened.cart
    item = item_of(cart)
    goods = item.goods || raise(ArgumentError, 'a cart item has no SKU')
    item.quantity = BigDecimal(@quantity)
    offer = Orders::Carts::Check.call(cart, goods:, quantity: @quantity, user_id: @owner.user_id)
    item.save!
    Orders::Carts::View.of(cart, offer, removed: opened.removed)
  end

  private

  def item_of(cart)
    cart.items.to_a.find { it.id == @item_id } ||
      raise(Orders::Carts::Refused.new(:cart_item_not_found, status: :not_found))
  end
end
