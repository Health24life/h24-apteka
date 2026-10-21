# frozen_string_literal: true

# What the endpoints of «Мої товари» and «Мої аптеки» share. A list belongs to an account, so a guest is refused rather
# than served an empty one, and nothing is kept for a guest. Adding and taking out answer with no body and may be
# repeated.
module FavoriteActions
  extend ActiveSupport::Concern

  included do
    before_action :no_store
    before_action :require_user

    rescue_from Favorites::Refused do |refused|
      render_error(refused.code, status: refused.status, details: refused.details)
    end
  end

  def update
    Favorites::Entries::Add.call(favorites_kind, user_id: current_user_id, target_id: target_id)
    head :no_content
  end

  def destroy
    Favorites::Entries::Remove.call(favorites_kind, user_id: current_user_id, target_id: target_id)
    head :no_content
  end

  private

  def require_user
    render_error(:unauthorized, status: :unauthorized) unless current_user_id
  end

  def target_id = params[favorites_kind.key]
end
