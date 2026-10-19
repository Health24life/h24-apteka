# frozen_string_literal: true

# Opens the cart of the one who asks for any use: finds it and takes out what became unusable. No cart, or one that
# went whole, is refused, with the reason when it went.
class Orders::Carts::Opening
  def self.call(owner) = tidy(Orders::Carts::Find.call(owner) || not_found)

  def self.tidy(cart)
    tidied = Orders::Carts::Tidy.call(cart)
    open = tidied.cart || not_found(tidied.reason)
    Orders::Carts::Opened.new(cart: open, removed: tidied.removed)
  end

  def self.not_found(reason = nil)
    raise Orders::Carts::Refused.new(:cart_not_found, status: :not_found, details: reason && { reason: })
  end
end
