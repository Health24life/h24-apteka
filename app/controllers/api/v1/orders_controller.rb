# frozen_string_literal: true

# The cart of a guest or a user, which is an order in the cart state: made by its first item, shown with the live prices
# of its drugstore, and cleared for good. Its owner reaches it by its token; a signed-in user finds the token of their
# cart through `current`.
class Api::V1::OrdersController < ApiController
  include CartActions

  def show = render_cart(Orders::Carts::Show.call(cart_owner(params[:token])))

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

  def destroy
    Orders::Carts::Clear.call(Orders::Carts::Opening.call(cart_owner(params[:token])).cart)
    head :no_content
  end

  def current = render_cart(Orders::Carts::Show.call(cart_owner))
end
