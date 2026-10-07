# frozen_string_literal: true

# Saves the dictionaries of the provider's catalog; each entry only needs an id and a name.
class Catalog::Sync::Savers::Dictionary
  MODELS = {
    forms: Catalog::Goods::Form, measures: Catalog::Goods::Measure, price_groups: Catalog::Goods::PriceGroup,
    temperature_modes: Catalog::Goods::TemperatureMode, restrictions: Catalog::Goods::Restriction,
    brands: Catalog::Drugstore::Brand
  }.freeze
  # A brand keeps its picture: the dictionary lists names only, and the picture arrives with a drugstore.
  NAME_ATTRIBUTE = { brands: :name }.freeze

  def initialize(linker, tracker)
    @linker = linker
    @tracker = tracker
  end

  def call(dictionaries)
    MODELS.each do |key, model|
      dictionaries.fetch(key, []).each { save_entry(model, NAME_ATTRIBUTE.fetch(key, :name_uk), it) }
    end
  end

  private

  def save_entry(model, attribute, entry)
    external_id = entry[:external_id]
    @tracker.guard(model.name, external_id, entry) do
      @linker.sync(model, external_id, { attribute => entry[:name] })
      @tracker.processed!
    end
  end
end
