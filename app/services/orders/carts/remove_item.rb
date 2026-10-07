# frozen_string_literal: true

# Removes an item from its cart. A cart is never kept empty, so the cart goes together with its last item. Only a cart
# is removed: an order that was already sent keeps its record even without items. Returns the cart, which tells the
# caller whether it was removed (+destroyed?+).
class Orders::Carts::RemoveItem
  def self.call(item) = new(item).call

  def initialize(item)
    @item = item
  end

  def call
    order = @item.order
    @item.destroy!
    order.destroy! if order.cart? && !order.items.exists?
    order
  end
end
