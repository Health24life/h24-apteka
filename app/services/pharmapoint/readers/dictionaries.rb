# frozen_string_literal: true

# The dictionaries answer holds seven lists under their own keys. The flat category list is skipped: it has no
# parents, so the category tree is the source of the hierarchy.
class Pharmapoint::Readers::Dictionaries
  KEYS = {
    'goods_form' => :forms, 'goods_measure' => :measures, 'goods_price_group' => :price_groups,
    'goods_temperature_mode' => :temperature_modes, 'goods_restrictions' => :restrictions,
    'drugstore_brands' => :brands
  }.freeze

  def self.call(body) = new.call(body)

  def call(body)
    data = Pharmapoint::Readers::Base.hash_or_empty(Pharmapoint::Readers::Base.envelope(body))
    KEYS.to_h { |key, name| [ name, Pharmapoint::Readers::Base.list(data[key]).filter_map { entry(it) } ] }
  end

  private

  def entry(record)
    return unless record.is_a?(Hash)

    external_id = Pharmapoint::Readers::Base.external_id(record['id'])
    { external_id:, name: Pharmapoint::Readers::Base.name(record) } if external_id
  end
end
