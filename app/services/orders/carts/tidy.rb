# frozen_string_literal: true

# Takes out of a cart what became unusable after it was made, every time the cart is used, as the cart model leaves it
# to the API. A disabled provider or a drugstore hidden or withdrawn ends the whole cart; a SKU hidden or withdrawn,
# alone or with its group, ends its item, and the cart goes with its last item.
class Orders::Carts::Tidy
  def self.call(cart) = new(cart).call

  def initialize(cart)
    @cart = cart
  end

  def call
    reason = cart_reason
    return gone(reason, []) if reason

    removed = @cart.items.includes(goods: :goods_group).filter_map { remove(it) }
    return gone(:items_removed, removed) if removed.any? && !@cart.items.exists?

    Orders::Carts::Tidied.new(cart: @cart, removed:, reason: nil)
  end

  private

  def cart_reason
    drugstore = @cart.drugstore
    return :provider_disabled unless @cart.provider.active?

    :drugstore_hidden if drugstore.hidden? || drugstore.withdrawn?
  end

  def remove(item)
    goods = item.goods
    reason = goods && goods_reason(goods)
    return unless goods && reason

    item.destroy!
    Orders::Carts::Removed.new(reason:, goods:)
  end

  def goods_reason(goods)
    group = goods.goods_group
    return :goods_hidden if goods.hidden? || group.hidden?

    :goods_withdrawn if goods.withdrawn? || group.withdrawn?
  end

  def gone(reason, removed)
    @cart.destroy!
    Orders::Carts::Tidied.new(cart: nil, removed:, reason:)
  end
end
