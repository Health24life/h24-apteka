class CreateCatalogGoodsInstructionSections < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_goods_instruction_sections do |t|
      t.references :goods, null: false, foreign_key: { to_table: :catalog_goods }, index: false
      t.integer :position, null: false
      t.string :code, null: false
      t.string :anchor, null: false
      t.string :source_title, null: false

      t.timestamps
    end

    add_index :catalog_goods_instruction_sections, %i[goods_id anchor], unique: true,
                                                                        name: 'index_catalog_instruction_sections_on_goods_and_anchor'
    add_index :catalog_goods_instruction_sections, %i[goods_id position], unique: true,
                                                                          name: 'index_catalog_instruction_sections_on_goods_and_position'
    add_check_constraint :catalog_goods_instruction_sections, 'position >= 1',
                         name: 'catalog_goods_instruction_sections_position_check'
    add_check_constraint :catalog_goods_instruction_sections, "anchor ~ '^[a-z0-9]+(-[a-z0-9]+)*$'",
                         name: 'catalog_goods_instruction_sections_anchor_check'

    create_table :catalog_goods_instruction_section_translations do |t|
      t.references :catalog_goods_instruction_section, null: false, foreign_key: { on_delete: :cascade },
                                                       index: false
      t.string :locale, null: false
      t.text :body_html

      t.timestamps
    end

    add_index :catalog_goods_instruction_section_translations, %i[catalog_goods_instruction_section_id locale],
              unique: true, name: 'index_catalog_instruction_section_translations_uniqueness'
  end
end
