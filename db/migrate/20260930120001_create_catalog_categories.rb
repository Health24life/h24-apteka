class CreateCatalogCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_categories do |t|
      t.references :parent, foreign_key: { to_table: :catalog_categories }
      t.string :slug, null: false
      t.integer :depth, null: false, default: 0
      t.jsonb :name, null: false

      t.timestamps
    end

    add_index :catalog_categories, :slug, unique: true
    add_check_constraint :catalog_categories, 'depth >= 0', name: 'catalog_categories_depth_check'
    add_check_constraint :catalog_categories, 'parent_id IS NULL OR parent_id <> id',
                         name: 'catalog_categories_parent_check'
    add_check_constraint :catalog_categories, "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) <= 100",
                         name: 'catalog_categories_slug_check'
  end
end
