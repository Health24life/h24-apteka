# frozen_string_literal: true

# The pages a sitemap lists, read in batches as slug and the moment their content last changed. The moment is the
# latest change of any table the page is built from, so a sync that changed nothing leaves it where it was.
class Seo::Sitemaps::Entries
  BATCH = 5_000

  def self.categories(&) = each(Catalog::Category.with_shown_goods, category_changed_at, &)

  def self.goods(&) = each(Catalog::Goods.shown, goods_changed_at, &)

  def self.each(scope, changed_at, &)
    scope.in_batches(of: BATCH) { it.reorder(:id).pluck(:slug, Arel.sql(changed_at)).each(&) }
  end

  def self.category_changed_at
    <<~SQL.squish
      GREATEST(catalog_categories.updated_at, (#{setting_changed_at('Catalog::Category', 'catalog_categories')}))
    SQL
  end

  def self.goods_changed_at
    <<~SQL.squish
      GREATEST(catalog_goods.updated_at,
        (SELECT MAX(updated_at) FROM catalog_goods_translations WHERE catalog_goods_id = catalog_goods.id),
        (SELECT updated_at FROM catalog_goods_groups WHERE id = catalog_goods.goods_group_id),
        (SELECT MAX(updated_at) FROM catalog_goods_group_translations WHERE catalog_goods_group_id = catalog_goods.goods_group_id),
        (SELECT producer.updated_at FROM catalog_producers producer JOIN catalog_goods_groups owner
          ON owner.producer_id = producer.id WHERE owner.id = catalog_goods.goods_group_id),
        (#{setting_changed_at('Catalog::Goods', 'catalog_goods')}))
    SQL
  end

  def self.setting_changed_at(type, table)
    "SELECT updated_at FROM seo_page_settings WHERE settable_type = '#{type}' AND settable_id = #{table}.id"
  end

  private_class_method :each, :category_changed_at, :goods_changed_at, :setting_changed_at
end
