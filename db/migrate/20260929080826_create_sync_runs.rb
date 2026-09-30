class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_runs do |t|
      t.references :provider, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.string :status, null: false, default: 'running'
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :processed_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.jsonb :progress, null: false, default: {}
      t.text :error_message

      t.timestamps
    end

    add_index :sync_runs, %i[provider_id kind started_at]
    add_check_constraint :sync_runs,
                         "status IN ('running', 'succeeded', 'completed_with_failures', 'failed')",
                         name: 'sync_runs_status_check'
  end
end
