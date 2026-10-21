class AddBookedIndexToOrders < ActiveRecord::Migration[8.1]
  def change
    add_index :orders,
              %i[user_id personal_data_consent_at],
              where: "state <> 'cart'",
              name: 'index_orders_on_user_id_booked'
  end
end
