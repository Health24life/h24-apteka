class MoveCatalogGoodsInstructionToTranslations < ActiveRecord::Migration[8.1]
  def change
    remove_column :catalog_goods, :instruction_html, :text
    add_column :catalog_goods_translations, :instruction_html, :text
    add_column :catalog_goods, :instruction_source_html, :text
  end
end
