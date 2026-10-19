# frozen_string_literal: true

# A sent order opened by the link its owner shared, so someone else can pick it up: the numbers, the drugstore, the
# items and the status, without the client's data or the owner's token. Nothing can be changed by the link.
class Api::V1::Shared::OrdersController < ApiController
  include CartActions

  def show
    order = Orders::Bookings::Open.shared(params[:share_token])
    render json: { order: Orders::Bookings::OrderBlueprint.render_as_hash(order, shared: true) }
  end
end
