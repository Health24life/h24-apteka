# frozen_string_literal: true

# The dictionaries answer holds seven lists under their own keys. The flat category list is skipped: it has no
# parents, so the category tree is the source of the hierarchy.
class Pharmapoint::Readers::Dictionaries
  include Pharmapoint::Readers::Base

  def self.call(body) = new.call(body)

  def call(body)
    data = hash_or_empty(envelope(body))
    Pharmapoint::Dictionaries.new(
      forms: entries(data, 'goods_form'), measures: entries(data, 'goods_measure'),
      price_groups: entries(data, 'goods_price_group'), temperature_modes: entries(data, 'goods_temperature_mode'),
      restrictions: entries(data, 'goods_restrictions'), brands: entries(data, 'drugstore_brands')
    )
  end

  private

  def entries(data, key) = list_at(data, key).filter_map { entry(it) }

  def entry(record)
    return unless record.is_a?(Hash)

    external_id = id_at(record, 'id')
    Pharmapoint::DictionaryEntry.new(external_id:, name: name(record)) if external_id
  end
end
