# frozen_string_literal: true

# A cart opened by the link its owner shared: anyone with the link sees the drugstore, the items and their live prices,
# and changes nothing. The owner's token is not given.
class Api::V1::Shared::OrdersController < ApiController
  include CartActions

  def show = render_cart(Orders::Carts::Show.shared(params[:share_token]), shared: true)
end
