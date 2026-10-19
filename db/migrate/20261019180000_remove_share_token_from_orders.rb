class RemoveShareTokenFromOrders < ActiveRecord::Migration[8.1]
  def change
    remove_index :orders, :share_token, unique: true, name: 'index_orders_on_share_token'
    remove_column :orders, :share_token, :string, null: false
  end
end
