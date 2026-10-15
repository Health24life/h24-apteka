# frozen_string_literal: true

# Saves the SKU of a page of saved goods groups in bulk, and the instruction of each. What a SKU only names by id
# (dictionary entries) must already be imported. A SKU that cannot be saved is a failure of its own and does not take
# the page down.
class Catalog::Sync::Savers::Goods
  def initialize(linker, tracker)
    @linker = linker
    @tracker = tracker
  end

  def call(groups, items)
    pairs = items.flat_map { |item| entries(groups.fetch(item.external_id), item.goods) }
    saved = Catalog::Sync::BulkSave.new(@linker, @tracker).call(Catalog::Goods, pairs.map(&:first))
    @tracker.processed!(pairs.count { |entry, goods| store_instruction(saved[entry.external_id], goods) })
  end

  private

  def entries(group, goods) = goods.filter_map { entry(group, it) }

  # A SKU that names a dictionary entry the catalog lacks is logged here and left out of the batch.
  def entry(group, goods)
    @tracker.guard(Catalog::Goods.name, goods.external_id, goods) do
      attributes = attributes(group, goods)
      [ Catalog::Sync::BulkSave::Entry.new(external_id: goods.external_id, attributes:, payload: goods), goods ]
    end
  end

  def store_instruction(record, goods)
    return unless record

    @tracker.guard(Catalog::Goods.name, goods.external_id, goods) do
      Catalog::Sync::InstructionStore.call(record, goods.card.instruction_html)
      true
    end
  end

  def attributes(group, goods)
    { goods_group: group, name_uk: goods.name, morion_code: goods.morion_code, withdrawn: false }
      .merge(card_attributes(goods.card), pack_attributes(goods.pack), references(goods.references))
  end

  def card_attributes(card)
    {
      release_form: card.release_form,
      dosage: card.dosage,
      mnn: card.mnn,
      composition: card.composition,
      image_paths: card.image_paths,
      is_recipe: card.is_recipe,
      is_strict_recipe: card.is_strict_recipe,
      in_medication_program: card.in_medication_program
    }
  end

  def pack_attributes(pack)
    {
      pack_unit_name: pack.unit_name,
      pack_quantity_in_pack: pack.quantity_in_pack,
      pack_quantity_unit_in_pack: pack.quantity_unit_in_pack,
      pack_quantity_in_unit: pack.quantity_in_unit
    }
  end

  def references(refs)
    {
      form: @linker.fetch(Catalog::Goods::Form, refs.form),
      measure: @linker.fetch(Catalog::Goods::Measure, refs.measure),
      price_group: @linker.fetch(Catalog::Goods::PriceGroup, refs.price_group),
      temperature_mode: @linker.fetch(Catalog::Goods::TemperatureMode, refs.temperature_mode)
    }.merge(restrictions(refs))
  end

  def restrictions(refs)
    {
      adult_restriction: restriction(refs.adult_restriction),
      child_restriction: restriction(refs.child_restriction),
      diabetic_restriction: restriction(refs.diabetic_restriction),
      driver_restriction: restriction(refs.driver_restriction),
      pregnant_and_lactating_restriction: restriction(refs.pregnant_and_lactating_restriction)
    }
  end

  def restriction(external_id) = @linker.fetch(Catalog::Goods::Restriction, external_id)
end
