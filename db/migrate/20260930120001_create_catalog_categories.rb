class CreateCatalogCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_categories do |t|
      t.references :parent, foreign_key: { to_table: :catalog_categories }
      t.string :slug, null: false
      t.integer :depth, null: false, default: 0

      t.timestamps
    end

    add_index :catalog_categories, :slug, unique: true
    add_check_constraint :catalog_categories, 'depth >= 0', name: 'catalog_categories_depth_check'
    add_check_constraint :catalog_categories, 'parent_id IS NULL OR parent_id <> id',
                         name: 'catalog_categories_parent_check'

    create_table :catalog_category_translations do |t|
      t.references :catalog_category, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :locale, null: false
      t.string :name

      t.timestamps
    end

    add_index :catalog_category_translations, %i[catalog_category_id locale], unique: true,
                                                                              name: 'index_catalog_category_translations_uniqueness'
  end
end
