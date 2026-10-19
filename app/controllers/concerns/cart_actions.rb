# frozen_string_literal: true

# What the endpoints of the cart share: the owner of the request, the refusals of the cart and how a cart is answered.
# A guest is known by the secret token of their cart in the X-Cart-Token header, a user by the session; the API takes
# no cookies.
module CartActions
  extend ActiveSupport::Concern

  QUANTITY = 1..Order::Item::MAX_QUANTITY

  included do
    before_action :no_store

    rescue_from Orders::Carts::Refused do |refused|
      retry_after = refused.retry_after
      response.headers['Retry-After'] = retry_after.to_s if retry_after
      render_error(refused.code, status: refused.status, details: refused.details)
    end
  end

  private

  def cart_owner
    @cart_owner ||= Orders::Carts::Owner.new(user_id: current_user_id, token: request.headers['X-Cart-Token'].presence)
  end

  def render_cart(view, status: :ok)
    render json: { cart: Orders::Carts::CartBlueprint.render_as_hash(view, guest: cart_owner.guest?) }, status:
  end

  # Whole packs only, so a fraction or a string is refused before the provider is asked.
  def quantity
    value = params.to_unsafe_h['quantity']
    return value if value.is_a?(Integer) && QUANTITY.cover?(value)

    raise Orders::Carts::Refused.new(:invalid_quantity, status: :unprocessable_content)
  end
end
