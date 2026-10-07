# frozen_string_literal: true

# Saves the dictionaries of the provider's catalog; each entry only needs an id and a name.
class Catalog::Sync::DictionarySaver
  def initialize(linker, tracker)
    @linker = linker
    @tracker = tracker
  end

  def call(dictionaries)
    save_all(Catalog::GoodsForm, :name_uk, dictionaries.forms)
    save_all(Catalog::GoodsMeasure, :name_uk, dictionaries.measures)
    save_all(Catalog::GoodsPriceGroup, :name_uk, dictionaries.price_groups)
    save_all(Catalog::GoodsTemperatureMode, :name_uk, dictionaries.temperature_modes)
    save_all(Catalog::GoodsRestriction, :name_uk, dictionaries.restrictions)
    # A brand keeps its picture: the dictionary lists names only, and the picture arrives with a drugstore.
    save_all(Catalog::DrugstoreBrand, :name, dictionaries.brands)
  end

  private

  def save_all(model, attribute, entries) = entries.each { save_entry(model, attribute, it) }

  def save_entry(model, attribute, entry)
    @tracker.guard(model.name, entry.external_id, entry) do
      @linker.sync(model, entry.external_id, { attribute => entry.name })
      @tracker.processed!
    end
  end
end
