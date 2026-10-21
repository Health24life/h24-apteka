# frozen_string_literal: true

# «Мої товари» of the signed-in user: a SKU, that is a release form, dosage and pack, rather than a trade name.
class Api::V1::Favorites::GoodsController < ApiController
  include FavoriteActions

  def index
    goods = Favorites::Goods::List.call(user_id: current_user_id)
    render json: { goods: Favorites::GoodsBlueprint.render_as_hash(goods) }
  end

  private

  def favorites_kind = Favorites::GOODS
end
