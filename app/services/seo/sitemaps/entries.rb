# frozen_string_literal: true

# The pages a sitemap lists, read in batches as slug and the moment their content last changed. The moment is the
# latest change of any table the page is built from, so a sync that changed nothing leaves it where it was. A page is
# listed exactly when its robots allow indexing: an operator's override wins over the rules, as on the page itself.
class Seo::Sitemaps::Entries
  BATCH = 5_000

  def self.categories(&)
    indexed = Catalog::Category.with_shown_goods.or(Catalog::Category.where(id: forced('Catalog::Category', 'index')))
    each(indexed.where.not(id: forced('Catalog::Category', 'noindex')), category_changed_at, &)
  end

  def self.goods(&) = each(Catalog::Goods.shown.where.not(id: forced('Catalog::Goods', 'noindex')), goods_changed_at, &)

  # The ids of the records whose override forces the given robots.
  def self.forced(type, robots) = Seo::Override.where(target_type: type, robots:).select(:target_id)

  def self.each(scope, changed_at, &)
    scope.in_batches(of: BATCH) { it.reorder(:id).pluck(:slug, Arel.sql(changed_at)).each(&) }
  end

  def self.category_changed_at
    <<~SQL.squish
      GREATEST(catalog_categories.updated_at, (#{override_changed_at('Catalog::Category', 'catalog_categories')}))
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
        (#{override_changed_at('Catalog::Goods', 'catalog_goods')}))
    SQL
  end

  # The texts set by hand: the row with the short ones and the translations with the SEO text.
  def self.override_changed_at(type, table)
    <<~SQL.squish
      SELECT GREATEST(seo_override.updated_at, MAX(translation.updated_at)) FROM seo_overrides seo_override
      LEFT JOIN seo_override_translations translation ON translation.seo_override_id = seo_override.id
      WHERE seo_override.target_type = '#{type}' AND seo_override.target_id = #{table}.id GROUP BY seo_override.id
    SQL
  end

  private_class_method :forced, :each, :category_changed_at, :goods_changed_at, :override_changed_at
end
