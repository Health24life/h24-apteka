class CreateCatalogAtcClasses < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_atc_classes do |t|
      t.references :parent, foreign_key: { to_table: :catalog_atc_classes }
      t.string :atc_code, null: false
      t.jsonb :name, null: false, default: {}

      t.timestamps
    end

    add_index :catalog_atc_classes, :atc_code, unique: true
    add_check_constraint :catalog_atc_classes, 'parent_id IS NULL OR parent_id <> id',
                         name: 'catalog_atc_classes_parent_check'

    create_table :catalog_atc_class_hierarchies, primary_key: %i[ancestor_id descendant_id generations] do |t|
      t.references :ancestor, null: false, index: false, foreign_key: { to_table: :catalog_atc_classes, on_delete: :cascade }
      t.references :descendant, null: false, foreign_key: { to_table: :catalog_atc_classes, on_delete: :cascade }
      t.integer :generations, null: false
    end
  end
end
