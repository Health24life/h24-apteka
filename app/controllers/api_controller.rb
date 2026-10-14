# frozen_string_literal: true

# Base of the public API the front calls. A request without a token is served as a guest; a token that is there but
# expired or invalid is refused, so a client never silently drops to guest. The token is read from the Authorization
# header only: the API takes no cookies.
class ApiController < ActionController::API
  include H24Auth::SessionContext

  private

  # PaperTrail would otherwise resolve the session of every request just to name the author of a version.
  def user_for_paper_trail = nil

  def h24_require_session
    reason = current_session_error
    render_error(:unauthorized, status: :unauthorized) if reason && reason != :absent
  end

  def h24_request_token = request.headers['Authorization']

  # Every error answers with a stable machine code and a message in Ukrainian.
  def render_error(code, status:)
    message = I18n.t(code, scope: 'api_controller.errors', locale: :uk)
    render json: { error: { code: code.to_s, message: } }, status:
  end
end
