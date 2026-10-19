# frozen_string_literal: true

# Booking the cart of its token: the client's data, the consent and the prices the user agreed to; the same call tries
# again an order whose sending failed. Guarded by Cloudflare Turnstile.
class Api::V1::Orders::BookingsController < ApiController
  include CartActions
  include RailsCloudflareTurnstile::ControllerHelpers

  def create
    return render_error(:turnstile_failed, status: :forbidden) unless turnstile_passed?

    request = Orders::Bookings::Request.from(params.to_unsafe_h)
    result = Orders::Bookings::Book.call(cart_owner(params[:order_token]), request)
    return render_error(:booking_submission_failed, status: :bad_gateway) unless result.submitted

    render json: { order: Orders::Bookings::OrderBlueprint.render_as_hash(result.order) }, status: :created
  end

  private

  # Production never books without the check, even when its keys are missing.
  def turnstile_passed?
    return false if Rails.env.production? && !RailsCloudflareTurnstile.enabled?

    cloudflare_turnstile_ok?
  end
end
