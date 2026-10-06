class CreateCatalogGoods < ActiveRecord::Migration[8.1]
  RESTRICTIONS = %i[adult_restriction child_restriction diabetic_restriction driver_restriction
                    pregnant_and_lactating_restriction].freeze

  def change
    create_table :catalog_goods do |t|
      t.references :goods_group, null: false, foreign_key: { to_table: :catalog_goods_groups }
      t.references :form, foreign_key: { to_table: :catalog_goods_forms }, index: false
      t.references :measure, foreign_key: { to_table: :catalog_goods_measures }, index: false
      t.references :price_group, foreign_key: { to_table: :catalog_goods_price_groups }, index: false
      t.references :temperature_mode, foreign_key: { to_table: :catalog_goods_temperature_modes }, index: false
      RESTRICTIONS.each do |restriction|
        t.references restriction, foreign_key: { to_table: :catalog_goods_restrictions }, index: false
      end
      t.integer :core_inn_id
      t.string :dosage
      t.text :composition
      t.string :mnn
      t.string :release_form
      t.string :morion_code
      t.string :pack_unit_name
      t.integer :pack_quantity_in_pack
      t.integer :pack_quantity_unit_in_pack
      t.integer :pack_quantity_in_unit
      t.jsonb :image_paths, null: false, default: []
      t.text :instruction_html
      t.boolean :is_recipe, null: false, default: false
      t.boolean :is_strict_recipe, null: false, default: false
      t.boolean :in_medication_program, null: false, default: false
      t.boolean :withdrawn, null: false, default: false
      t.boolean :hidden, null: false, default: false

      t.timestamps
    end

    %i[pack_quantity_in_pack pack_quantity_unit_in_pack pack_quantity_in_unit].each do |column|
      add_check_constraint :catalog_goods, "#{column} IS NULL OR #{column} >= 0", name: "catalog_goods_#{column.to_s.delete_prefix('pack_quantity_')}_check"
    end
    add_check_constraint :catalog_goods, "jsonb_typeof(image_paths) = 'array'", name: 'catalog_goods_image_paths_check'

    create_table :catalog_goods_translations do |t|
      t.references :catalog_goods, null: false, foreign_key: { to_table: :catalog_goods, on_delete: :cascade },
                                   index: false
      t.string :locale, null: false
      t.string :name

      t.timestamps
    end

    add_index :catalog_goods_translations, %i[catalog_goods_id locale], unique: true,
                                                                        name: 'index_catalog_goods_translations_uniqueness'
  end
end
