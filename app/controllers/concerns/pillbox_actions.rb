# frozen_string_literal: true

# What the endpoints of the pillbox share. A plan belongs to an account, so a guest is refused; a plan or an item of
# another user is answered as missing.
module PillboxActions
  extend ActiveSupport::Concern

  included do
    before_action :no_store
    before_action :require_user
  end

  private

  def require_user
    render_error(:unauthorized, status: :unauthorized) unless current_user_id
  end
end
