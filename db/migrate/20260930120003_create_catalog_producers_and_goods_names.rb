class CreateCatalogProducersAndGoodsNames < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_producers do |t|
      t.string :name, null: false
      t.string :country
      t.string :country_code, limit: 2

      t.timestamps
    end

    add_check_constraint :catalog_producers, "country_code IS NULL OR country_code ~ '^[A-Z]{2}$'",
                         name: 'catalog_producers_country_code_check'

    create_table :catalog_goods_names do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
