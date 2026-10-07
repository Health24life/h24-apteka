# frozen_string_literal: true

# Saves the dictionaries of the provider's catalog; each entry only needs an id and a name.
class Catalog::Sync::Savers::Dictionary
  def initialize(linker, tracker)
    @linker = linker
    @tracker = tracker
  end

  def call(dictionaries)
    save_all(Catalog::Goods::Form, :name_uk, dictionaries.forms)
    save_all(Catalog::Goods::Measure, :name_uk, dictionaries.measures)
    save_all(Catalog::Goods::PriceGroup, :name_uk, dictionaries.price_groups)
    save_all(Catalog::Goods::TemperatureMode, :name_uk, dictionaries.temperature_modes)
    save_all(Catalog::Goods::Restriction, :name_uk, dictionaries.restrictions)
    # A brand keeps its picture: the dictionary lists names only, and the picture arrives with a drugstore.
    save_all(Catalog::Drugstore::Brand, :name, dictionaries.brands)
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
