# frozen_string_literal: true

# Saves the dictionaries of the provider's catalog; each entry only needs an id and a name.
class Catalog::Sync::DictionarySaver
  MODELS = {
    forms: Catalog::GoodsForm, measures: Catalog::GoodsMeasure, price_groups: Catalog::GoodsPriceGroup,
    temperature_modes: Catalog::GoodsTemperatureMode, restrictions: Catalog::GoodsRestriction,
    brands: Catalog::DrugstoreBrand
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
