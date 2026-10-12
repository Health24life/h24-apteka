class CreateCatalogDrugstoreBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_drugstore_brands do |t|
      t.string :name, null: false
      t.string :image_path

      t.timestamps
    end
  end
end
