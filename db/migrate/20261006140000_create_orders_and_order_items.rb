class CreateOrdersAndOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :drugstore, null: false, foreign_key: { to_table: :catalog_drugstores }, index: false
      t.references :provider, null: false, foreign_key: true, index: false
      t.integer :user_id
      t.string :state, null: false, default: 'cart'
      t.string :token, null: false
      t.string :share_token, null: false

      t.timestamps
    end

    add_index :orders, :token, unique: true
    add_index :orders, :share_token, unique: true
    add_check_constraint :orders, "state IN ('cart', 'submitted', 'submission_failed')", name: 'orders_state_check'

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }
      t.references :goods, foreign_key: { to_table: :catalog_goods }, index: false
      t.decimal :quantity, precision: 12, scale: 4, null: false
      t.decimal :price, precision: 12, scale: 2
      t.decimal :total, precision: 12, scale: 2

      t.timestamps
    end

    add_check_constraint :order_items, 'quantity > 0', name: 'order_items_quantity_check'
  end
end
