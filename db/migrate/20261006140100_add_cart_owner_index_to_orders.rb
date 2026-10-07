class AddCartOwnerIndexToOrders < ActiveRecord::Migration[8.1]
  def change
    add_index :orders, :user_id, unique: true, where: "state = 'cart' AND user_id IS NOT NULL",
                                 name: 'index_orders_on_user_id_cart'
  end
end
