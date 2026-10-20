# frozen_string_literal: true

# Asks the provider of a cart, live, what its drugstore has of the items the cart holds with the change made but not
# saved, and refuses the change when the drugstore cannot cover the SKU being added or changed. The answer serves the
# cart shown after the change, so the provider is asked once.
class Orders::Carts::Check
  def self.call(cart, goods:, quantity:, user_id: nil) = new(cart, goods, quantity, user_id).call

  def initialize(cart, goods, quantity, user_id)
    @cart = cart
    @goods = goods
    @quantity = quantity
    @user_id = user_id
  end

  def call
    offer = known(Orders::Carts.offer(@cart, @user_id))
    line = offer.line_for(@goods.id)
    available = line&.available_quantity.to_i
    return offer if line&.fulfilled && available >= @quantity

    # The partner may mark a line not fulfilled when it has fewer packs than asked, so the packs it has decide.
    refuse(:goods_not_in_drugstore, :unprocessable_content) unless available.positive? && available < @quantity

    refuse(:quantity_exceeds_stock, :unprocessable_content, details: { available_quantity: available })
  end

  private

  def known(offer)
    case offer
    when Orders::Offers::DrugstoreOffer then offer.known? ? offer : unavailable
    when Orders::Offers::Failure then offer.rate_limited? ? busy(offer.retry_after) : unavailable
    else unavailable
    end
  end

  def busy(retry_after)
    raise Orders::Carts::Refused.new(:cart_check_busy, status: :service_unavailable, retry_after:)
  end

  def unavailable = refuse(:cart_check_unavailable, :service_unavailable)

  def refuse(code, status, details: nil) = raise(Orders::Carts::Refused.new(code, status:, details:))
end
