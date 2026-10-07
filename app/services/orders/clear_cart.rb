# frozen_string_literal: true

# Clears a cart for good: a cart is never kept empty, so clearing it removes the cart together with its items. Only a
# cart can be cleared, an order that was already sent must stay. Returns the removed cart.
class Orders::ClearCart
  def self.call(order) = new(order).call

  def initialize(order)
    @order = order
  end

  def call
    raise ArgumentError, 'only a cart can be cleared' unless @order.cart?

    @order.destroy!
  end
end
