class CreateFavoriteGoodsAndFavoriteDrugstores < ActiveRecord::Migration[8.1]
  def change
    create_table :favorite_goods do |t|
      t.integer :user_id, null: false
      t.references :goods, null: false, foreign_key: { to_table: :catalog_goods, on_delete: :cascade }
      t.datetime :created_at, null: false
    end

    add_index :favorite_goods, %i[user_id goods_id], unique: true

    create_table :favorite_drugstores do |t|
      t.integer :user_id, null: false
      t.references :drugstore, null: false, foreign_key: { to_table: :catalog_drugstores, on_delete: :cascade }
      t.datetime :created_at, null: false
    end

    add_index :favorite_drugstores, %i[user_id drugstore_id], unique: true
  end
end
