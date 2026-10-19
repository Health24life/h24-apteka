# frozen_string_literal: true

# The cart of the user or the guest: shown with live prices of its drugstore, and cleared for good.
class Api::V1::CartsController < ApiController
  include CartActions

  def show = render_cart(Orders::Carts::Show.call(cart_owner))

  def destroy
    Orders::Carts::Clear.call(Orders::Carts::Opening.call(cart_owner).cart)
    head :no_content
  end
end
