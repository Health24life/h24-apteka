# frozen_string_literal: true

# Turns the exceptions an endpoint lets out into answers of the API. Every error answers with a stable machine code and
# a message in Ukrainian, and some with details the front acts on. A record not found answers with the code
# `<model>_not_found` (`Pillbox::PlanItem` gives `pillbox_plan_item_not_found`), so a model needs its text among the
# errors of the API.
module Exceptionable
  extend ActiveSupport::Concern
  include Pundit::Authorization

  included do
    rescue_from Refused, with: :refused
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from Pundit::NotAuthorizedError, with: :access_denied
    rescue_from ActionController::ParameterMissing, with: :parameter_missing
  end

  private

  def render_error(code, status:, details: nil)
    message = I18n.t(code, scope: 'api_controller.errors', locale: :uk)
    error = { code: code.to_s, message: }
    error[:details] = details if details
    render json: { error: }, status:
  end

  def refused(refused)
    retry_after = refused.retry_after
    response.headers['Retry-After'] = retry_after.to_s if retry_after
    render_error(refused.code, status: refused.status, details: refused.details)
  end

  def not_found(error)
    model = error.model
    render_error(model ? "#{model.underscore.tr('/', '_')}_not_found" : :not_found, status: :not_found)
  end

  def access_denied = render_error(:forbidden, status: :forbidden)

  def parameter_missing(error)
    render_error(:parameter_missing, status: :bad_request, details: { param: error.param })
  end
end
