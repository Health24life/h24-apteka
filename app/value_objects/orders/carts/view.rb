# frozen_string_literal: true

# A cart as the user sees it: its drugstore, its items with live prices, the total of what is available, and what was
# taken out of it on the way. `prices_available` is false when the provider gave nothing on the cart.
class Orders::Carts::View < Data.define(:cart, :prices_available, :items, :removed)
  def self.of(cart, offer, removed: [])
    known = offer if offer.is_a?(Orders::Offers::DrugstoreOffer) && offer.known?
    items = cart.items.order(:id).includes(:goods).map do |item|
      goods_id = item.goods_id
      Orders::Carts::ItemView.new(item:, line: goods_id && known&.line_for(goods_id))
    end
    new(cart:, prices_available: !known.nil?, items:, removed:)
  end

  def total = items.filter_map(&:total).sum(BigDecimal(0))
end
