class CreateProviderRequestLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_request_logs do |t|
      t.references :provider, null: false, foreign_key: true
      t.references :sync_run, foreign_key: { on_delete: :nullify }
      t.integer :user_id
      t.string :category, null: false
      t.string :http_method, null: false
      t.string :path, null: false
      t.jsonb :query, null: false, default: {}
      t.jsonb :request_headers, null: false, default: {}
      t.jsonb :response_headers, null: false, default: {}
      t.jsonb :request_body
      t.jsonb :response_body
      t.integer :response_status
      t.string :outcome, null: false
      t.string :error_class
      t.integer :duration_ms, null: false, default: 0
      t.integer :attempt, null: false, default: 1

      t.datetime :created_at, null: false
    end

    add_index :provider_request_logs, %i[category created_at]
    add_index :provider_request_logs, %i[user_id created_at]

    add_check_constraint :provider_request_logs, "category IN ('booking', 'search', 'refresh', 'other')",
                         name: 'provider_request_logs_category_check'
    add_check_constraint :provider_request_logs,
                         "outcome IN ('success', 'http_error', 'timeout', 'connection_error', 'invalid_response')",
                         name: 'provider_request_logs_outcome_check'
    add_check_constraint :provider_request_logs, 'attempt >= 1', name: 'provider_request_logs_attempt_check'
    add_check_constraint :provider_request_logs, 'duration_ms >= 0', name: 'provider_request_logs_duration_check'
    add_check_constraint :provider_request_logs,
                         "(outcome IN ('timeout', 'connection_error')) = (response_status IS NULL)",
                         name: 'provider_request_logs_status_check'
  end
end
