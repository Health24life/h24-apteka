# frozen_string_literal: true

# A SKU of «Мої товари» with the static data of its card, as a row of the search shows it, no prices or stock; whether
# the catalog still shows it, and when it was added.
class Favorites::GoodsBlueprint < Blueprinter::Base
  fields :id, :slug, :release_form, :dosage, :is_recipe, :is_strict_recipe

  field :name, preload: :translations
  field(:pack) do |goods|
    {
      unit_name: goods.pack_unit_name,
      quantity_in_pack: goods.pack_quantity_in_pack,
      quantity_unit_in_pack: goods.pack_quantity_unit_in_pack,
      quantity_in_unit: goods.pack_quantity_in_unit
    }
  end
  field(:trade_name, preload: { goods_group: :goods_name }) { |goods| goods.goods_group.goods_name&.name }
  field(:producer, preload: { goods_group: :producer }) do |goods|
    producer = goods.goods_group.producer
    { name: producer&.name, country_code: producer&.country_code }
  end
  field :shown?, name: :available, preload: :goods_group
  field(:added_at) { |goods| goods.added_at.iso8601 }
end
