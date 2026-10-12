# frozen_string_literal: true

class CreateCatalogDictionaries < ActiveRecord::Migration[8.1]
  DICTIONARIES = %i[goods_forms goods_measures goods_price_groups goods_temperature_modes goods_restrictions].freeze

  def change
    DICTIONARIES.each do |dictionary|
      table = :"catalog_#{dictionary}"

      create_table table do |t|
        t.jsonb :name, null: false

        t.timestamps
      end
    end
  end
end
