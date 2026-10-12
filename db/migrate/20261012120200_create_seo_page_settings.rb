class CreateSeoPageSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_page_settings do |t|
      t.references :settable, polymorphic: true, null: false, index: { unique: true }
      t.string :title
      t.string :description
      t.string :h1
      t.text :seo_text

      t.timestamps
    end

    add_check_constraint :seo_page_settings, "settable_type IN ('Catalog::Goods', 'Catalog::Category')",
                         name: 'seo_page_settings_type_check'
  end
end
