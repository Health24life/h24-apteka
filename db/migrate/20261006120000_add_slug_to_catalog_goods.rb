class AddSlugToCatalogGoods < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_goods, :slug, :string, null: false
    add_index :catalog_goods, :slug, unique: true
    add_check_constraint :catalog_goods, "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) <= 100",
                         name: 'catalog_goods_slug_check'
  end
end
