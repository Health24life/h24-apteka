class CreateCatalogDrugstores < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_drugstores do |t|
      t.references :brand, foreign_key: { to_table: :catalog_drugstore_brands }
      t.string :name
      t.string :drugstore_legal_entity_name, null: false
      t.string :drugstore_legal_entity_code, null: false
      t.string :phone
      t.string :mobile_phone
      t.string :email
      t.string :ext_drugstore_id
      t.jsonb :week_working_hours, null: false, default: []
      t.boolean :work_with_reimbursement, null: false, default: false
      t.boolean :withdrawn, null: false, default: false
      t.boolean :hidden, null: false, default: false
      t.boolean :incomplete, null: false, default: false

      t.timestamps
    end

    add_check_constraint :catalog_drugstores, "drugstore_legal_entity_code ~ '^[0-9]{8}([0-9]{2})?$'",
                         name: 'catalog_drugstores_legal_entity_code_check'
    # jsonb_array_length raises on anything that is not an array, so no separate type check is needed.
    add_check_constraint :catalog_drugstores, 'jsonb_array_length(week_working_hours) IN (0, 7)',
                         name: 'catalog_drugstores_week_hours_check'

    create_table :catalog_drugstore_addresses do |t|
      t.references :drugstore, null: false, foreign_key: { to_table: :catalog_drugstores, on_delete: :cascade },
                               index: { unique: true }
      t.string :address, null: false
      t.string :city
      t.string :state
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.integer :core_region_id
      t.integer :core_settlement_id
      t.integer :core_city_district_id
      t.integer :core_metro_station_id

      t.timestamps
    end

    add_check_constraint :catalog_drugstore_addresses, 'latitude BETWEEN -90 AND 90',
                         name: 'catalog_drugstore_addresses_latitude_check'
    add_check_constraint :catalog_drugstore_addresses, 'longitude BETWEEN -180 AND 180',
                         name: 'catalog_drugstore_addresses_longitude_check'
  end
end
