# frozen_string_literal: true

# Tells which of a provider's hits the catalog shows: a SKU it has saved and shows leads to its card, a SKU it lacks or
# has withdrawn is listed but cannot be opened, and a SKU an operator hid, alone or with its group, is not listed at
# all. One query per page: the SKU links of the provider, and the hidden groups for SKU the catalog does not have yet.
class Catalog::Search::LocalGoods
  # What the catalog knows of a SKU or a goods group of the provider.
  class Known < Data.define(:id, :slug, :hidden, :withdrawn); end

  # Whether each SKU of the last page has a link to the catalog, by the provider's id: what the sync would ask again.
  attr_reader :goods_links

  def self.call(provider, hits) = new(provider).call(hits)

  def initialize(provider)
    @provider = provider
    @goods_links = {}
  end

  def call(hits)
    return [] if hits.empty?

    goods, hidden_groups = known(hits)
    @goods_links = hits.to_h { [ it.external_id, goods.key?(it.external_id) ] }
    hits.filter_map { shown(it, goods[it.external_id]) unless hidden_groups.include?(it.group_external_id) }
  end

  private

  def shown(hit, local)
    return hit unless local
    return if local.hidden

    local.withdrawn ? hit : hit.with(ready: true, id: local.id, slug: local.slug)
  end

  # The SKU by the provider's id, and the ids of the hidden groups.
  def known(hits)
    rows = Provider::Link.connection.select_rows("#{goods_sql(hits)} UNION ALL #{hidden_groups_sql(hits)}")
    goods, groups = rows.partition { it.first == 'goods' }
    known = goods.to_h { |row| [ row[1], Known.new(id: row[2], slug: row[3], hidden: row[4], withdrawn: row[5]) ] }
    [ known, groups.to_set(&:second) ]
  end

  def goods_sql(hits)
    links(Catalog::Goods, hits.map(&:external_id))
      .joins('INNER JOIN catalog_goods ON catalog_goods.id = provider_links.linkable_id')
      .joins('INNER JOIN catalog_goods_groups ON catalog_goods_groups.id = catalog_goods.goods_group_id')
      .select(
        "'goods'",
        'provider_links.external_id',
        'catalog_goods.id',
        'catalog_goods.slug',
        'catalog_goods.hidden OR catalog_goods_groups.hidden',
        'catalog_goods.withdrawn OR catalog_goods_groups.withdrawn'
      ).to_sql
  end

  def hidden_groups_sql(hits)
    links(Catalog::Goods::Group, hits.map(&:group_external_id).uniq)
      .joins('INNER JOIN catalog_goods_groups ON catalog_goods_groups.id = provider_links.linkable_id')
      .where(catalog_goods_groups: { hidden: true })
      .select("'group'", 'provider_links.external_id', 'NULL::bigint', 'NULL::varchar', 'TRUE', 'FALSE')
      .to_sql
  end

  def links(model, external_ids)
    Provider::Link.where(provider_id: @provider.id, linkable_type: model.name, external_id: external_ids)
  end
end
