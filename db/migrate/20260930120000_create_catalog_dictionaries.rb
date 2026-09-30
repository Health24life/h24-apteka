# frozen_string_literal: true

class CreateCatalogDictionaries < ActiveRecord::Migration[8.1]
  DICTIONARIES = {
    goods_forms: 'goods_form',
    goods_measures: 'goods_measure',
    goods_price_groups: 'goods_price_group',
    goods_temperature_modes: 'goods_temperature_mode',
    goods_restrictions: 'goods_restriction'
  }.freeze

  def change
    DICTIONARIES.each do |plural, singular|
      table = :"catalog_#{plural}"
      translations = :"catalog_#{singular}_translations"
      reference = :"catalog_#{singular}"

      create_table table do |t|
        t.timestamps
      end

      # Built by hand: the globalize helper adds neither the foreign key nor the (fk, locale) unique index.
      create_table translations do |t|
        t.references reference, null: false, foreign_key: { to_table: table, on_delete: :cascade }, index: false
        t.string :locale, null: false
        t.string :name

        t.timestamps
      end

      add_index translations, [:"#{reference}_id", :locale], unique: true, name: "index_#{translations}_uniqueness"
    end
  end
end
