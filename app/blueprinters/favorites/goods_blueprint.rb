# frozen_string_literal: true

# A SKU of «Мої товари» with the static data of its card, as a row of the search shows it, no prices or stock; whether
# the catalog still shows it, and when it was added.
class Favorites::GoodsBlueprint < Blueprinter::Base
  field(:id) { |row| row.goods.id }
  field(:slug) { |row| row.goods.slug }
  field(:name) { |row| row.goods.name }
  field(:release_form) { |row| row.goods.release_form }
  field(:dosage) { |row| row.goods.dosage }
  field(:pack) do |row|
    goods = row.goods
    {
      unit_name: goods.pack_unit_name,
      quantity_in_pack: goods.pack_quantity_in_pack,
      quantity_unit_in_pack: goods.pack_quantity_unit_in_pack,
      quantity_in_unit: goods.pack_quantity_in_unit
    }
  end
  field(:is_recipe) { |row| row.goods.is_recipe }
  field(:is_strict_recipe) { |row| row.goods.is_strict_recipe }
  field(:trade_name) { |row| row.goods.goods_group.goods_name&.name }
  field(:producer) do |row|
    producer = row.goods.goods_group.producer
    { name: producer&.name, country_code: producer&.country_code }
  end
  field :available?, name: :available
  field(:added_at) { |row| row.added_at.iso8601 }
end
