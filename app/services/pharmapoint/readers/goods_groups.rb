# frozen_string_literal: true

# Goods groups with their release forms (SKU). Only static card data is read: price, stock, VAT, pre-order and the
# counts of drugstores depend on the drugstore and the moment, so they are not copied from the answer at all.
class Pharmapoint::Readers::GoodsGroups
  include Pharmapoint::Readers::Base

  def self.page(body, page:, per_page:) = new.page(body, page:, per_page:)

  def self.one(body) = new.one(body)

  def page(body, page:, per_page:)
    items = list(envelope(body)).filter_map { group(it) }
    meta = hash_at(hash_or_empty(body), 'meta')
    Pharmapoint::Page.new(items:, page:, per_page:, total: int_at(meta, 'total') || items.size)
  end

  def one(body)
    data = envelope(body)
    group(data.is_a?(Array) ? data.first : data) || raise(Pharmapoint::InvalidResponse, 'the answer has no goods group')
  end

  private

  def group(record)
    return unless record.is_a?(Hash)

    external_id = id_at(record, 'id')
    build_group(external_id, record) if external_id
  end

  def build_group(external_id, record)
    Pharmapoint::GoodsGroup.new(
      external_id:, name: name(record), included_to_offers: affirmative_at?(record, 'included_to_offers'),
      producer: producer(record['goods_producer']), goods_name: goods_name(record['goods_name']),
      atc_class: atc_class(record), categories: categories(record),
      goods: list_at(record, 'release_forms').filter_map { Pharmapoint::Readers::Goods.call(it) }
    )
  end

  def producer(value)
    record = hash_or_empty(value)
    external_id = id_at(record, 'id')
    return unless external_id

    Pharmapoint::Producer.new(external_id:, name: text_at(record, 'name'), country: text_at(record, 'country'),
                              country_code: text_at(record, 'country_code')&.upcase)
  end

  def goods_name(value)
    record = hash_or_empty(value)
    external_id = id_at(record, 'id')
    Pharmapoint::GoodsName.new(external_id:, name: text_at(record, 'name')) if external_id
  end

  # Ancestors come from the root down and do not include the class itself.
  def atc_class(record)
    entry = atc_entry(record['goods_atc_class'])
    return unless entry

    Pharmapoint::AtcClass.new(external_id: entry.external_id, atc_code: entry.atc_code, name: entry.name,
                              ancestors: list_at(record, 'goods_atc_class_tree').filter_map { atc_entry(it) })
  end

  def atc_entry(value)
    record = hash_or_empty(value)
    external_id = id_at(record, 'id')
    return unless external_id

      Pharmapoint::AtcEntry.new(external_id:, atc_code: text_at(record, 'atc_code'),
                                name: text_at(record, 'name'))
  end

  # The paths run from the root to the leaf; a category's `tree_id` is the index of its path.
  def categories(record)
    paths = list_at(record, 'goods_categories_trees')
    list_at(record, 'goods_categories').filter_map { group_category(it, paths) }
  end

  def group_category(value, paths)
    record = hash_or_empty(value)
    external_id = id_at(record, 'id')
    return unless external_id

    Pharmapoint::GroupCategory.new(external_id:, name: name(record),
                                   path: category_path(paths, int_at(record, 'tree_id')))
  end

  def category_path(paths, index)
    nodes = index ? paths[index] : nil
    nodes.is_a?(Array) ? nodes.filter_map { path_node(it) } : []
  end

  def path_node(value)
    record = hash_or_empty(value)
    external_id = id_at(record, 'id')
    Pharmapoint::PathNode.new(external_id:, name: name(record)) if external_id
  end
end
