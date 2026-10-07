# frozen_string_literal: true

# Goods groups with their release forms (SKU). Only static card data is read: price, stock, VAT, pre-order and the
# counts of drugstores depend on the drugstore and the moment, so they are not copied from the answer at all.
class Pharmapoint::Readers::GoodsGroups
  GOODS_FIELDS = {
    release_form: %w[release_form text], dosage: %w[dosage text], mnn: %w[mnn text],
    composition: %w[supplement_facts text], instruction_html: %w[instruction text], image_paths: %w[image_url images],
    is_recipe: %w[is_recipe flag], is_strict_recipe: %w[is_strict_recipe flag],
    in_medication_program: %w[in_medication_program flag]
  }.freeze
  REFERENCE_FIELDS = {
    form: %w[form_id id], measure: %w[measure_id id], price_group: %w[price_group_id id],
    temperature_mode: %w[temperature_mode_id id], adult_restriction: %w[adult_restriction_id id],
    child_restriction: %w[child_restriction_id id], diabetic_restriction: %w[diabetic_restriction_id id],
    driver_restriction: %w[driver_restriction_id id],
    pregnant_and_lactating_restriction: %w[pregnant_and_lactating_restriction_id id]
  }.freeze
  PACK_FIELDS = {
    unit_name: %w[unit_name text], quantity_in_pack: %w[quantity_in_pack int],
    quantity_unit_in_pack: %w[quantity_unit_in_pack int], quantity_in_unit: %w[quantity_in_unit int]
  }.freeze

  def self.page(body, page:, per_page:) = new.page(body, page:, per_page:)

  def self.one(body) = new.one(body)

  def page(body, page:, per_page:)
    items = base.list(base.envelope(body)).filter_map { group(it) }
    meta = base.hash_or_empty(base.hash_or_empty(body)['meta'])
    total = base.integer(meta['total']) || items.size
    Pharmapoint::Page.new(items:, page:, per_page:, total:)
  end

  def one(body)
    data = base.envelope(body)
    group(data.is_a?(Array) ? data.first : data) || raise(Pharmapoint::InvalidResponse, 'the answer has no goods group')
  end

  private

  def base = Pharmapoint::Readers::Base

  def group(record)
    return unless record.is_a?(Hash)

    external_id = base.external_id(record['id'])
    return unless external_id

    { external_id:, name: base.name(record), included_to_offers: base.affirmative?(record['included_to_offers']),
      goods: base.list(record['release_forms']).filter_map { goods(it) } }.merge(links(record))
  end

  def links(record)
    { producer: producer(record['goods_producer']), goods_name: goods_name(record['goods_name']),
      atc_class: atc_class(record['goods_atc_class'], record['goods_atc_class_tree']), categories: categories(record) }
  end

  def producer(record)
    record = base.hash_or_empty(record)
    external_id = base.external_id(record['id'])
    return unless external_id

    { external_id:, name: base.text(record['name']), country: base.text(record['country']),
      country_code: base.text(record['country_code'])&.upcase }
  end

  def goods_name(record)
    record = base.hash_or_empty(record)
    external_id = base.external_id(record['id'])
    { external_id:, name: base.text(record['name']) } if external_id
  end

  # Ancestors come from the root down and do not include the class itself.
  def atc_class(record, ancestors)
    entry = atc_entry(record)
    entry&.merge(ancestors: base.list(ancestors).filter_map { atc_entry(it) })
  end

  def atc_entry(record)
    record = base.hash_or_empty(record)
    external_id = base.external_id(record['id'])
    { external_id:, atc_code: base.text(record['atc_code']), name: base.text(record['name']) } if external_id
  end

  # The paths run from the root to the leaf; a category's `tree_id` is the index of its path.
  def categories(record)
    paths = base.list(record['goods_categories_trees'])
    base.list(record['goods_categories']).filter_map do |category|
      node = category_node(category)
      node&.merge(path: category_path(paths, base.integer(base.hash_or_empty(category)['tree_id'])))
    end
  end

  def category_path(paths, index)
    nodes = index ? paths[index] : nil
    nodes.is_a?(Array) ? nodes.filter_map { category_node(it) } : []
  end

  def category_node(record)
    record = base.hash_or_empty(record)
    external_id = base.external_id(record['id'])
    { external_id:, name: base.name(record) } if external_id
  end

  def goods(record)
    return unless record.is_a?(Hash)

    external_id = base.external_id(record['id'])
    { external_id:, name: base.name(record), morion_code: morion_code(record), **card(record) } if external_id
  end

  def card(record)
    base.pick(record, GOODS_FIELDS).merge(base.pick(record, REFERENCE_FIELDS),
                                          pack: base.pick(base.hash_or_empty(record['pack_info']), PACK_FIELDS))
  end

  # The partner's barcode is the Morion code, not an EAN, so it is stored as the Morion code.
  def morion_code(record) = base.external_id(record['morion_id']) || base.text(record['barcode'])
end
