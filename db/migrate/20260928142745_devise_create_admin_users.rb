# frozen_string_literal: true

class DeviseCreateAdminUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.datetime :remember_created_at
      t.boolean :is_active, null: false, default: true

      t.timestamps null: false
    end

    add_index :admin_users, :email, unique: true
  end
end
