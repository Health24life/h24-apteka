# frozen_string_literal: true

# What a filter selects now, to check it before it is saved or published: how many SKUs and the first of them by name.
# The filter needs no saving, as the selection reads only its parameters and prescription scope.
class Seo::Filters::Preview < Data.define(:count, :goods)
  LIMIT = 50

  def self.call(filter)
    scope = Seo::Filters::Goods.call(filter)
    goods = scope.joins(:translations).where(catalog_goods_translations: { locale: 'uk' })
                 .order('catalog_goods_translations.name', :id).limit(LIMIT).preload(:translations)
    new(count: scope.count, goods: goods.to_a)
  end
end
