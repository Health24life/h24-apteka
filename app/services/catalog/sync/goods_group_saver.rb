# frozen_string_literal: true

# Saves a goods group with everything it carries: producer, trade name, ATC class, categories and release forms. What
# the group lacks in the catalog yet (producer, ATC class, category) is created from its own data; what it only
# names by id (dictionary entries) must already be imported. A release form that cannot be saved is a failure of
# its own and does not take the group down.
class Catalog::Sync::GoodsGroupSaver
  RESTRICTIONS = %i[adult_restriction child_restriction diabetic_restriction driver_restriction
                    pregnant_and_lactating_restriction].freeze
  CARD_ATTRIBUTES = %i[morion_code release_form dosage mnn composition is_recipe is_strict_recipe
                       in_medication_program].freeze

  def initialize(linker, tracker)
    @linker = linker
    @tracker = tracker
  end

  def call(item)
    group = save_group(item)
    save_categories(group, item[:categories])
    item[:goods].each { save_goods(group, it) }
    @tracker.processed!
    group
  end

  private

  def save_group(item)
    attributes = { name_uk: item[:name], included_to_offers: item[:included_to_offers], withdrawn: false,
                   producer: producer(item[:producer]), goods_name: goods_name(item[:goods_name]),
                   atc_class: atc_class(item[:atc_class]) }
    @linker.sync(Catalog::GoodsGroup, item[:external_id], attributes)
  end

  def producer(record)
    return unless record

    @linker.sync(Catalog::Producer, record[:external_id], record.slice(:name, :country, :country_code))
  end

  def goods_name(record)
    @linker.sync(Catalog::GoodsName, record[:external_id], record.slice(:name)) if record
  end

  # The ancestors are saved first, root down, so each class can name its parent.
  def atc_class(record)
    return unless record

    # @type var parent: Catalog::AtcClass?
    parent = nil
    record[:ancestors].each { |ancestor| parent = save_atc_class(ancestor, parent) }
    save_atc_class(record, parent)
  end

  def save_atc_class(record, parent)
    @linker.sync(Catalog::AtcClass, record[:external_id], { atc_code: record[:atc_code], name_uk: record[:name],
                                                            parent: })
  end

  # The first category of the provider's list is the primary one.
  def save_categories(group, categories)
    leaves = categories.map { ensure_category(it) }
    group.goods_group_categories.where.not(category_id: leaves.map(&:id)).delete_all
    group.goods_group_categories.update_all(is_primary: false) # rubocop:disable Rails/SkipsModelValidations
    leaves.each_with_index do |category, index|
      group.goods_group_categories.find_or_initialize_by(category:).update!(is_primary: index.zero?)
    end
  end

  # A category the tree import has not brought yet is built from the path the group carries, root down.
  def ensure_category(category)
    *ancestors, leaf = category[:path].presence || [ category.slice(:external_id, :name) ]
    # @type var parent: Catalog::Category?
    parent = nil
    ancestors.each { |node| parent = ensure_category_node(node, parent) }
    ensure_category_node(leaf, parent)
  end

  def ensure_category_node(node, parent)
    @linker.find(Catalog::Category, node[:external_id]) ||
      @linker.sync(Catalog::Category, node[:external_id], { name_uk: node[:name], parent: }) do |record|
        Catalog::CategorySaver.call(record)
      end
  end

  def save_goods(group, record)
    @tracker.guard('Catalog::Goods', record[:external_id], record) do
      goods = @linker.sync(Catalog::Goods, record[:external_id], goods_attributes(group, record))
      Catalog::Sync::InstructionStore.call(goods, record[:instruction_html])
      @tracker.processed!
    end
  end

  def goods_attributes(group, record)
    { goods_group: group, name_uk: record[:name], image_paths: record[:image_paths], withdrawn: false,
      **record.slice(*CARD_ATTRIBUTES), **pack_attributes(record[:pack]), **references(record) }
  end

  def pack_attributes(pack)
    { pack_unit_name: pack[:unit_name], pack_quantity_in_pack: pack[:quantity_in_pack],
      pack_quantity_unit_in_pack: pack[:quantity_unit_in_pack], pack_quantity_in_unit: pack[:quantity_in_unit] }
  end

  def references(record)
    { form: @linker.fetch(Catalog::GoodsForm, record[:form]),
      measure: @linker.fetch(Catalog::GoodsMeasure, record[:measure]),
      price_group: @linker.fetch(Catalog::GoodsPriceGroup, record[:price_group]),
      temperature_mode: @linker.fetch(Catalog::GoodsTemperatureMode, record[:temperature_mode]) }
      .merge(restrictions(record))
  end

  def restrictions(record)
    RESTRICTIONS.index_with { |name| @linker.fetch(Catalog::GoodsRestriction, record[name]) }
  end
end
