class CreateProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :providers do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :kind, null: false
      t.boolean :active, null: false, default: true
      t.boolean :supports_delivery, null: false, default: false
      t.boolean :supports_e_recipe, null: false, default: false

      t.timestamps
    end

    add_index :providers, :code, unique: true
    add_check_constraint :providers, "kind IN ('external', 'own')", name: 'providers_kind_check'
  end
end
