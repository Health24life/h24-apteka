# frozen_string_literal: true

# The cart of a guest or a user, which is an order in the cart state: made by its first item, shown with the live prices
# of its drugstore, and cleared for good. Its owner reaches it by its token; a signed-in user finds the token of their
# cart through `current`.
class Api::V1::OrdersController < ApiController
  include CartActions

  # The bookings of the signed-in user's account; a guest's bookings have no history.
  def index
    user_id = current_user_id
    return render_error(:unauthorized, status: :unauthorized) unless user_id

    history = Orders::Bookings::History.call(user_id:, page: params[:page], per_page: params[:per_page])
    render json: {
      orders: Orders::Bookings::HistoryBlueprint.render_as_hash(history.orders),
      page: history.page,
      per_page: history.per_page,
      has_more: history.has_more
    }
  end

  # The cart, or the order it became once booked.
  def show
    owner = cart_owner(params[:token])
    order = Orders::Bookings::Open.owned(owner)
    return render_cart(Orders::Carts::Show.call(owner)) unless order

    render_order(order, owner)
  end

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
