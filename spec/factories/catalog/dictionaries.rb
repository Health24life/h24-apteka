# frozen_string_literal: true

FactoryBot.define do
  {
    catalog_goods_form: [ 'Catalog::GoodsForm', 'Таблетки' ],
    catalog_goods_measure: [ 'Catalog::GoodsMeasure', 'Упаковка' ],
    catalog_goods_price_group: [ 'Catalog::GoodsPriceGroup', 'Група 1' ],
    catalog_goods_temperature_mode: [ 'Catalog::GoodsTemperatureMode', 'Кімнатна' ],
    catalog_goods_restriction: [ 'Catalog::GoodsRestriction', 'Без обмежень' ]
  }.each do |name, (klass, title)|
    factory name, class: klass do
      name_uk { title }
    end
  end
end
