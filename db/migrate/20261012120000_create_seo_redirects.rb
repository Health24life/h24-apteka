class CreateSeoRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_redirects do |t|
      t.string :page_type, null: false
      t.string :slug, null: false
      t.references :redirectable, polymorphic: true, null: false, index: false

      t.datetime :created_at, null: false
    end

    add_index :seo_redirects, %i[page_type slug], unique: true
    add_index :seo_redirects, %i[redirectable_type redirectable_id]

    add_check_constraint :seo_redirects, "page_type IN ('goods', 'category')", name: 'seo_redirects_page_type_check'
    add_check_constraint :seo_redirects, "redirectable_type IN ('Catalog::Goods', 'Catalog::Category')",
                         name: 'seo_redirects_type_check'
    add_check_constraint :seo_redirects, "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) <= 100",
                         name: 'seo_redirects_slug_check'
  end
end
