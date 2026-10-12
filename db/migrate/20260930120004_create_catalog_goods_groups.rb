class CreateCatalogGoodsGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_goods_groups do |t|
      t.references :producer, foreign_key: { to_table: :catalog_producers }
      t.references :goods_name, foreign_key: { to_table: :catalog_goods_names }
      t.references :atc_class, foreign_key: { to_table: :catalog_atc_classes }
      t.boolean :included_to_offers, null: false, default: false
      t.boolean :withdrawn, null: false, default: false
      t.boolean :hidden, null: false, default: false

      t.timestamps
    end

    create_table :catalog_goods_group_translations do |t|
      t.references :catalog_goods_group, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :locale, null: false
      t.string :name

      t.timestamps
    end

    add_index :catalog_goods_group_translations, %i[catalog_goods_group_id locale], unique: true,
                                                                                    name: 'index_catalog_goods_group_translations_uniqueness'

    create_table :catalog_goods_group_categories do |t|
      t.references :goods_group, null: false, foreign_key: { to_table: :catalog_goods_groups, on_delete: :cascade },
                                 index: false
      t.references :category, null: false, foreign_key: { to_table: :catalog_categories }
      t.boolean :is_primary, null: false, default: false

      t.timestamps
    end

    add_index :catalog_goods_group_categories, %i[goods_group_id category_id], unique: true,
                                                                               name: 'index_catalog_goods_group_categories_uniqueness'
    add_index :catalog_goods_group_categories, :goods_group_id, unique: true, where: 'is_primary',
                                                                name: 'index_catalog_goods_group_categories_primary'
  end
end
