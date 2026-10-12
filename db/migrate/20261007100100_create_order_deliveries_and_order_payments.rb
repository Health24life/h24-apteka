class CreateOrderDeliveriesAndOrderPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :order_deliveries do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :delivery_type_code, null: false, default: 'pick_up'

      t.timestamps
    end

    add_check_constraint :order_deliveries,
                         "delivery_type_code IN ('pick_up', 'ukr_post', 'nova_poshta', 'meest_express', " \
                         "'justin', 'uklon', 'ipost')",
                         name: 'order_deliveries_type_check'

    create_table :order_delivery_addresses do |t|
      t.references :delivery, null: false, foreign_key: { to_table: :order_deliveries, on_delete: :cascade },
                              index: { unique: true }
      t.string :city, null: false
      t.string :street
      t.string :building
      t.string :post_office
      t.string :postal_code

      t.timestamps
    end

    add_check_constraint :order_delivery_addresses, "coalesce(btrim(city), '') <> ''",
                         name: 'order_delivery_addresses_city_check'
    add_check_constraint :order_delivery_addresses,
                         "coalesce(btrim(post_office), '') <> '' OR " \
                         "(coalesce(btrim(street), '') <> '' AND coalesce(btrim(building), '') <> '')",
                         name: 'order_delivery_addresses_place_check'
    add_check_constraint :order_delivery_addresses, "postal_code IS NULL OR postal_code ~ '^[0-9]{5}$'",
                         name: 'order_delivery_addresses_postal_code_check'

    create_table :order_payments do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :payment_type_code, null: false

      t.timestamps
    end

    add_check_constraint :order_payments, "payment_type_code IN ('cash_in_store', 'cash_on_delivery')",
                         name: 'order_payments_type_check'
  end
end
