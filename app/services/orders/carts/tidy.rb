# frozen_string_literal: true

# Takes out of a cart what became unusable after it was made, every time the cart is used, as the cart model leaves it
# to the API. A drugstore hidden or withdrawn ends the whole cart; a SKU hidden or withdrawn, alone or with its group,
# ends its item, and the cart goes with its last item. A disabled provider ends nothing, as it may come back. The items
# that stay are left loaded on the cart, with their SKUs.
class Orders::Carts::Tidy
  def self.call(cart) = new(cart).call

  def initialize(cart)
    @cart = cart
  end

  def call
    return gone(:drugstore_hidden, []) if drugstore_gone?

    @cart.items.reset
    ActiveRecord::Associations::Preloader.new(records: [ @cart ], associations: { items: { goods: :goods_group } }).call
    removed = @cart.items.to_a.filter_map { remove(it) }
    return gone(:items_removed, removed) if removed.any? && @cart.items.empty?

    Orders::Carts::Tidied.new(cart: @cart, removed:, reason: nil)
  end

  private

  def drugstore_gone?
    drugstore = @cart.drugstore
    drugstore.hidden? || drugstore.withdrawn?
  end

  def remove(item)
    goods = item.goods
    reason = goods && goods_reason(goods)
    return unless goods && reason

    @cart.items.destroy(item)
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
