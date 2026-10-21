# frozen_string_literal: true

# «Мої аптеки» of the signed-in user.
class Api::V1::Favorites::DrugstoresController < ApiController
  include FavoriteActions

  def index
    drugstores = Favorites::Drugstores::List.call(user_id: current_user_id)
    render json: { drugstores: Favorites::DrugstoreBlueprint.render_as_hash(drugstores) }
  end

  private

  def favorites_kind = Favorites::DRUGSTORES
end
