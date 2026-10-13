class CreateSeoOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_overrides do |t|
      t.references :target, polymorphic: true, null: false, index: { unique: true }
      t.jsonb :title, null: false, default: {}
      t.jsonb :description, null: false, default: {}
      t.jsonb :h1, null: false, default: {}
      t.string :robots, null: false, default: 'auto'

      t.timestamps
    end

    add_check_constraint :seo_overrides, "robots IN ('auto', 'index', 'noindex')", name: 'seo_overrides_robots_check'

    create_table :seo_override_translations do |t|
      t.references :seo_override, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :locale, null: false
      t.text :seo_text

      t.timestamps
    end

    add_index :seo_override_translations, %i[seo_override_id locale], unique: true,
                                                                      name: 'index_seo_override_translations_uniqueness'
  end
end
