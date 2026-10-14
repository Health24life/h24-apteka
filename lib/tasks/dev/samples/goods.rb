# frozen_string_literal: true

# One SKU of a goods group with all the fields the card shows.
module DevSamples::Goods
  module_function

  def call(provider, group, recipe:, **spec)
    name = "#{group.name_uk} #{spec[:dosage]}"
    sku = group.goods.joins(:translations).find_by(catalog_goods_translations: { name: }) ||
          Catalog::Goods.create!(goods_group: group, name_uk: name, is_recipe: recipe, **attributes(**spec))
    DevSamples.link(provider, sku, attrs: { 'name' => name })
  end

  def attributes(inn:, form:, dosage:)
    { dosage:, mnn: inn, release_form: form, composition: inn && "#{inn} — #{dosage}",
      form: DevSamples.by_name(Catalog::Goods::Form, form) || DevSamples.by_name(Catalog::Goods::Form, 'Таблетки'),
      measure: DevSamples.by_name(Catalog::Goods::Measure, 'Упаковка'),
      price_group: DevSamples.by_name(Catalog::Goods::PriceGroup, 'Звичайна ціна'),
      temperature_mode: DevSamples.by_name(Catalog::Goods::TemperatureMode, 'Кімнатна'),
      driver_restriction: DevSamples.by_name(Catalog::Goods::Restriction, 'З обережністю'),
      pack_quantity_in_pack: [ 10, 20, 30 ].sample, pack_unit_name: 'шт.', morion_code: rand(100_000..999_999).to_s }
  end
end
