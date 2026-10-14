# frozen_string_literal: true

# Saves a page of goods groups with everything they carry: producer, trade name, ATC class, categories and SKU. The
# groups are written in bulk; the trees, producers and trade names one by one, as a group needs them. What the group
# lacks in the catalog yet (producer, ATC class, category) is created from its own data. A group that cannot be saved is
# a failure of its own and does not take the page down.
class Catalog::Sync::Savers::GoodsGroup
  def initialize(linker, tracker)
    @linker = linker
    @tracker = tracker
  end

  def call(items)
    entries = items.filter_map { |item| guard(item) { entry(item) } }
    groups = Catalog::Sync::BulkSave.new(@linker, @tracker).call(Catalog::Goods::Group, entries)
    save_contents(groups, items.select { groups.key?(it.external_id) })
    @tracker.processed!(groups.size)
    groups
  end

  private

  def save_contents(groups, saved)
    saved.each { |item| guard(item) { save_categories(groups.fetch(item.external_id), item.categories) } }
    Catalog::Sync::Savers::Goods.new(@linker, @tracker).call(groups, saved)
  end

  def guard(item, &) = @tracker.guard(Catalog::Goods::Group.name, item.external_id, item, &)

  def entry(item)
    attributes = { name_uk: item.name, included_to_offers: item.included_to_offers, withdrawn: false,
                   producer: producer(item.producer), goods_name: goods_name(item.goods_name),
                   atc_class: atc_class(item.atc_class) }
    Catalog::Sync::BulkSave::Entry.new(external_id: item.external_id, attributes:, payload: item)
  end

  def producer(record)
    return unless record

    @linker.sync(Catalog::Producer, record.external_id,
                 { name: record.name, country: record.country, country_code: record.country_code })
  end

  def goods_name(record)
    @linker.sync(Catalog::Goods::Name, record.external_id, { name: record.name }) if record
  end

  # The ancestors are saved first, root down, so each class can name its parent.
  def atc_class(record)
    return unless record

    # @type var parent: Catalog::AtcClass?
    parent = nil
    record.ancestors.each { |ancestor| parent = save_atc_class(ancestor, parent) }
    save_atc_class(record, parent)
  end

  def save_atc_class(record, parent)
    @linker.sync(Catalog::AtcClass, record.external_id, { atc_code: record.atc_code, name_uk: record.name, parent: })
  end

  # The primary category is set once, to the first of the provider's list, and only for a group without one: the
  # breadcrumbs and the SEO template of the card follow it, and an editor may have chosen it by hand. The mark never
  # comes off a category that stays in the list, so a choice an editor makes while the import runs is not written over.
  def save_categories(group, categories)
    ids = categories.map { ensure_category(it).id }.uniq
    gone = group.goods_group_categories.where.not(category_id: ids)
    dropped = gone.find_by(is_primary: true)&.category
    gone.delete_all
    link_categories(group, ids) if ids.any?
    record_dropped_primary(group, dropped) if dropped
  end

  def link_categories(group, ids)
    rows = ids.map { { goods_group_id: group.id, category_id: it } }
    Catalog::Goods::Group::Category.insert_all(rows, unique_by: %i[goods_group_id category_id]) # rubocop:disable Rails/SkipsModelValidations
    primary = Catalog::Goods::Group::Category.where(goods_group_id: group.id, is_primary: true)
    Catalog::Goods::Group::Category.where(goods_group_id: group.id, category_id: ids.first)
                                   .where.not(goods_group_id: primary.select(:goods_group_id))
                                   .update_all(is_primary: true, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def record_dropped_primary(group, dropped)
    group.touch # rubocop:disable Rails/SkipsModelValidations
    primary = group.goods_group_categories.find_by(is_primary: true)&.category
    Catalog::PrimaryCategory::History.record(group:, from: dropped, to: primary, author: @linker.provider)
  end

  # A category the tree import has not brought yet is built from the path the group carries, root down.
  def ensure_category(category)
    nodes = if category.path.empty?
  [ Pharmapoint::PathNode.new(external_id: category.external_id,
                              name: category.name) ]
    else
  category.path
    end
    # @type var parent: Catalog::Category?
    parent = nil
    nodes.first(nodes.size - 1).each { |node| parent = ensure_category_node(node, parent) }
    ensure_category_node(nodes.fetch(-1), parent)
  end

  def ensure_category_node(node, parent)
    @linker.find(Catalog::Category, node.external_id) ||
      @linker.sync(Catalog::Category, node.external_id, { name_uk: node.name, parent: })
  end
end
