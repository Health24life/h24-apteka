class CreateSeoStaticPages < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_static_pages do |t|
      t.string :key
      t.jsonb :name, null: false, default: {}
      t.string :slug
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    add_index :seo_static_pages, :key, unique: true
    add_index :seo_static_pages, :slug, unique: true

    add_check_constraint :seo_static_pages,
                         "(key = 'home' AND slug IS NULL) OR " \
                         "(key IS NULL AND slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) <= 100)",
                         name: 'seo_static_pages_slug_check'

    create_table :seo_static_page_translations do |t|
      t.references :seo_static_page, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :locale, null: false
      t.text :content

      t.timestamps
    end

    add_index :seo_static_page_translations, %i[seo_static_page_id locale], unique: true,
                                                                            name: 'index_seo_static_page_translations_uniqueness'
  end
end
