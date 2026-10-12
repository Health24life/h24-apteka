class CreateSeoTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_templates do |t|
      t.string :page_type, null: false
      t.references :category, foreign_key: { to_table: :catalog_categories }, index: false
      t.boolean :is_recipe
      t.string :title, null: false
      t.string :description, null: false
      t.string :h1, null: false

      t.timestamps
    end

    add_index :seo_templates, %i[page_type category_id is_recipe], unique: true, nulls_not_distinct: true,
                                                                   name: 'index_seo_templates_uniqueness'
    add_index :seo_templates, :category_id

    add_check_constraint :seo_templates, "page_type IN ('home', 'category', 'goods', 'cart', 'order')",
                         name: 'seo_templates_page_type_check'
    add_check_constraint :seo_templates, "category_id IS NULL OR page_type IN ('category', 'goods')",
                         name: 'seo_templates_category_check'
    add_check_constraint :seo_templates, "is_recipe IS NULL OR page_type = 'goods'",
                         name: 'seo_templates_recipe_check'
  end
end
