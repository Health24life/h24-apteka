# frozen_string_literal: true

# The items of a cart, reached by the token of the cart. Every item put in or changed is checked live against what the
# drugstore of the cart has.
class Api::V1::Orders::ItemsController < ApiController
  include CartActions

  def create
    body = params.to_unsafe_h
    result = Orders::Carts::AddItem.call(
      owner,
      goods_id: body['goods_id'],
      drugstore_id: body['drugstore_id'],
      quantity:
    )
    render_cart(result.view)
  end

  def update = render_cart(Orders::Carts::ChangeQuantity.call(owner, item_id: params[:id], quantity:))

  # The cart goes with its last item; the front reads the cart again for the rest.
  def destroy
    cart = Orders::Carts::Opening.call(owner).cart
    item = cart.items.find_by(id: params[:id]) ||
           raise(Orders::Carts::Refused.new(:cart_item_not_found, status: :not_found))
    Orders::Carts::RemoveItem.call(item)
    head :no_content
  end

  private

  def owner = cart_owner(params[:order_token])
end
