class AddSentOrderDataToOrdersAndOrderItems < ActiveRecord::Migration[8.1]
  def change
    change_table :orders, bulk: true do |t|
      t.string :customer_first_name, limit: 100
      t.string :customer_last_name, limit: 100
      t.string :customer_middle_name, limit: 100
      t.string :customer_phone_number
      t.string :customer_email
      t.boolean :register_account, null: false, default: false
      t.datetime :personal_data_consent_at
      t.string :own_number
      t.string :provider_order_number
      t.string :provider_drugstore_external_id
      t.string :drugstore_name
      t.string :drugstore_address
      t.string :drugstore_phone
      t.string :status_name
      t.string :status_comment
      t.string :cancel_reason
      t.jsonb :progress, null: false, default: {}
      t.datetime :provider_updated_at
      t.datetime :status_synced_at
      t.jsonb :provider_payload, null: false, default: {}
    end

    add_index :orders, :own_number, unique: true
    add_index :orders, %i[provider_id provider_order_number], unique: true
    add_check_constraint :orders, "customer_phone_number IS NULL OR customer_phone_number ~ '^380[0-9]{9}$'",
                         name: 'orders_customer_phone_number_check'
    add_check_constraint :orders,
                         "state = 'cart' OR (personal_data_consent_at IS NOT NULL " \
                         "AND coalesce(btrim(own_number), '') <> '' " \
                         "AND coalesce(btrim(customer_first_name), '') <> '' " \
                         "AND coalesce(btrim(customer_phone_number), '') <> '' " \
                         "AND coalesce(btrim(provider_drugstore_external_id), '') <> '')",
                         name: 'orders_sent_data_check'
    add_check_constraint :orders, "state <> 'submitted' OR coalesce(btrim(provider_order_number), '') <> ''",
                         name: 'orders_submitted_provider_order_number_check'
    add_check_constraint :orders, "jsonb_typeof(progress) = 'object' AND jsonb_typeof(provider_payload) = 'object'",
                         name: 'orders_provider_objects_check'

    change_table :order_items, bulk: true do |t|
      t.string :provider_goods_external_id
      t.string :name
      t.string :producer
      t.string :release_form
      t.jsonb :image_paths, null: false, default: []
    end

    add_check_constraint :order_items, 'price >= 0 AND total >= 0', name: 'order_items_amounts_check'
    add_check_constraint :order_items, "jsonb_typeof(image_paths) = 'array'", name: 'order_items_image_paths_check'
  end
end
