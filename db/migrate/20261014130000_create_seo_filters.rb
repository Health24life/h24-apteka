class CreateSeoFilters < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_filters do |t|
      t.jsonb :name, null: false, default: {}
      t.string :slug, null: false
      t.jsonb :params, null: false, default: {}
      t.references :category, foreign_key: { to_table: :catalog_categories }, index: false
      t.integer :position, null: false, default: 0
      t.string :sort_order, null: false, default: 'name'
      t.string :recipe_scope, null: false, default: 'otc'
      t.boolean :published, null: false, default: false
      t.datetime :removed_at

      t.timestamps
    end

    add_index :seo_filters, :slug, unique: true
    add_index :seo_filters, %i[category_id position], where: 'published AND removed_at IS NULL',
                                                      name: 'index_seo_filters_listed'

    add_check_constraint :seo_filters, "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) <= 100",
                         name: 'seo_filters_slug_check'
    add_check_constraint :seo_filters, 'position >= 0', name: 'seo_filters_position_check'
    add_check_constraint :seo_filters, "sort_order IN ('name', 'newest')", name: 'seo_filters_sort_order_check'
    add_check_constraint :seo_filters, "recipe_scope IN ('otc', 'rx', 'any')", name: 'seo_filters_recipe_scope_check'
    add_check_constraint :seo_filters, 'removed_at IS NULL OR NOT published', name: 'seo_filters_removed_check'
  end
end
