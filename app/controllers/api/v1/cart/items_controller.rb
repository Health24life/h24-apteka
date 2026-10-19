# frozen_string_literal: true

# The items of the cart. The first item makes the cart, bound to the drugstore it is put in; every item put in or
# changed is checked live against what that drugstore has.
class Api::V1::Cart::ItemsController < ApiController
  include CartActions

  def create
    body = params.to_unsafe_h
    result = Orders::Carts::AddItem.call(
      cart_owner,
      goods_id: body['goods_id'],
      drugstore_id: body['drugstore_id'],
      quantity:
    )
    render_cart(result.view, status: result.created ? :created : :ok)
  end

  def update = render_cart(Orders::Carts::ChangeQuantity.call(cart_owner, item_id: params[:id], quantity:))

  # The cart goes with its last item; the front reads the cart again for the rest.
  def destroy
    cart = Orders::Carts::Opening.call(cart_owner).cart
    item = cart.items.find_by(id: params[:id]) ||
           raise(Orders::Carts::Refused.new(:cart_item_not_found, status: :not_found))
    Orders::Carts::RemoveItem.call(item)
    head :no_content
  end
end
