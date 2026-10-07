# frozen_string_literal: true

# The release forms (SKU) of a goods group: the static card, the packing and the dictionary entries it points at.
class Pharmapoint::Readers::Goods
  include Pharmapoint::Readers::Base

  def self.call(value) = new.call(value)

  def call(value)
    return unless value.is_a?(Hash)

    external_id = id_at(value, 'id')
    return unless external_id

    Pharmapoint::Goods.new(external_id:, name: name(value), morion_code: morion_code(value), card: card(value),
                           pack: pack(value), references: references(value))
  end

  private

  # The partner's barcode is the Morion code, not an EAN, so it is stored as the Morion code.
  def morion_code(record) = id_at(record, 'morion_id') || text_at(record, 'barcode')

  def card(record)
    Pharmapoint::GoodsCard.new(
      release_form: text_at(record, 'release_form'), dosage: text_at(record, 'dosage'), mnn: text_at(record, 'mnn'),
      composition: text_at(record, 'supplement_facts'), instruction_html: text_at(record, 'instruction'),
      image_paths: images_at(record, 'image_url'), is_recipe: affirmative_at?(record, 'is_recipe'),
      is_strict_recipe: affirmative_at?(record, 'is_strict_recipe'),
      in_medication_program: affirmative_at?(record, 'in_medication_program')
    )
  end

  def pack(record)
    pack = hash_at(record, 'pack_info')
    Pharmapoint::Pack.new(unit_name: text_at(pack, 'unit_name'), quantity_in_pack: int_at(pack, 'quantity_in_pack'),
                          quantity_unit_in_pack: int_at(pack, 'quantity_unit_in_pack'),
                          quantity_in_unit: int_at(pack, 'quantity_in_unit'))
  end

  def references(record)
    Pharmapoint::GoodsReferences.new(
      form: id_at(record, 'form_id'), measure: id_at(record, 'measure_id'),
      price_group: id_at(record, 'price_group_id'), temperature_mode: id_at(record, 'temperature_mode_id'),
      adult_restriction: id_at(record, 'adult_restriction_id'),
      child_restriction: id_at(record, 'child_restriction_id'),
      diabetic_restriction: id_at(record, 'diabetic_restriction_id'),
      driver_restriction: id_at(record, 'driver_restriction_id'),
      pregnant_and_lactating_restriction: id_at(record, 'pregnant_and_lactating_restriction_id')
    )
  end
end
