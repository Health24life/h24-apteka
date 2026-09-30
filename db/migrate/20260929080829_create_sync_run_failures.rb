class CreateSyncRunFailures < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_run_failures do |t|
      t.references :sync_run, null: false, foreign_key: { on_delete: :cascade }
      t.string :entity_type, null: false
      t.string :external_id, null: false
      t.string :error_class, null: false
      t.text :message
      t.jsonb :payload

      t.timestamps
    end
  end
end
