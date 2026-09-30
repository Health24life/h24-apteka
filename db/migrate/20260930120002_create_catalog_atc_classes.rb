class CreateCatalogAtcClasses < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_atc_classes do |t|
      t.references :parent, foreign_key: { to_table: :catalog_atc_classes }
      t.string :atc_code, null: false

      t.timestamps
    end

    add_index :catalog_atc_classes, :atc_code, unique: true
    add_check_constraint :catalog_atc_classes, 'parent_id IS NULL OR parent_id <> id',
                         name: 'catalog_atc_classes_parent_check'

    create_table :catalog_atc_class_translations do |t|
      t.references :catalog_atc_class, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :locale, null: false
      t.string :name

      t.timestamps
    end

    add_index :catalog_atc_class_translations, %i[catalog_atc_class_id locale], unique: true,
                                                                                name: 'index_catalog_atc_class_translations_uniqueness'
    add_check_constraint :catalog_atc_class_translations, "locale IN ('uk')",
                         name: 'catalog_atc_class_translations_locale_check'
  end
end
