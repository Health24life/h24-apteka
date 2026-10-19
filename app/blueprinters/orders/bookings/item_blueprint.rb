# frozen_string_literal: true

# An item of a sent order, as it was when it was sent: the name and the price confirmed then.
class Orders::Bookings::ItemBlueprint < Blueprinter::Base
  MONEY = Orders::Carts::CartBlueprint::MONEY

  fields :goods_id, :name

  field(:quantity) { |item| item.quantity.to_i }
  field(:price) { |item| MONEY.call(item.price) }
  field(:total) { |item| MONEY.call(item.total) }
end
