# frozen_string_literal: true

# An item of the cart with what the drugstore has of it right now. With no live data, the item has no price and is not
# available; an item the drugstore cannot cover in full stays in the cart, as stock comes back.
class Orders::Carts::ItemView < Data.define(:item, :line)
  def available?
    line = self.line
    return false unless line&.fulfilled

    line.available_quantity >= item.quantity
  end

  def available_quantity = line&.available_quantity

  def price
    line = self.line
    line.price if line && available?
  end

  def total
    price = self.price
    price * item.quantity if price
  end
end
