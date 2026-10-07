# frozen_string_literal: true

# The dictionaries answer holds seven lists under their own keys. The flat category list is skipped: it has no
# parents, so the category tree is the source of the hierarchy.
class Pharmapoint::Readers::Dictionaries
  def self.call(body) = new.call(body)

  def call(body)
    data = Pharmapoint::Readers::Base.hash_or_empty(Pharmapoint::Readers::Base.envelope(body))
    { forms: entries(data['goods_form']), measures: entries(data['goods_measure']),
      price_groups: entries(data['goods_price_group']), temperature_modes: entries(data['goods_temperature_mode']),
      restrictions: entries(data['goods_restrictions']), brands: entries(data['drugstore_brands']) }
  end

  private

  def entries(value) = Pharmapoint::Readers::Base.list(value).filter_map { entry(it) }

  def entry(record)
    return unless record.is_a?(Hash)

    external_id = Pharmapoint::Readers::Base.external_id(record['id'])
    { external_id:, name: Pharmapoint::Readers::Base.name(record) } if external_id
  end
end
