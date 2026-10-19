# frozen_string_literal: true

# The cart as the user sees it. The token is given to a guest only: it is the guest's key to the cart. Prices are in
# hryvnias as strings, live, and only for the items the drugstore has in full.
class Orders::Carts::CartBlueprint < Blueprinter::Base
  MONEY = ->(amount) { amount && ActiveSupport::NumberHelper.number_to_rounded(amount, precision: 2) }

  field(:token, if: ->(_name, _view, options) { options[:guest] }) { |view| view.cart.token }
  field(:drugstore) { |view| Catalog::DrugstoreBlueprint.render_as_hash(view.cart.drugstore) }
  field :prices_available
  field(:items) do |view|
    view.items.map do |line|
      item = line.item
      goods = item.goods
      {
        id: item.id,
        goods: goods && { id: goods.id, slug: goods.slug, name: goods.name },
        quantity: item.quantity.to_i,
        available: line.available?,
        available_quantity: line.available_quantity,
        price: MONEY.call(line.price),
        total: MONEY.call(line.total)
      }
    end
  end
  field(:total) { |view| MONEY.call(view.total) if view.prices_available }
  field(:removed) do |view|
    view.removed.map { { reason: it.reason.to_s, goods: { id: it.goods.id, name: it.goods.name } } }
  end
end
