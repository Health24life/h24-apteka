# frozen_string_literal: true

ActiveAdmin.register Provider::RequestLog, as: 'ProviderRequestLog' do
  menu parent: 'sync', priority: 2

  actions :index, :show
  config.batch_actions = false
  config.comments = false
  config.sort_order = 'id_desc'

  includes :provider

  filter :provider
  filter :category, as: :select, collection: proc { Provider::RequestLog.categories.keys }
  filter :outcome, as: :select, collection: proc { Provider::RequestLog.outcomes.keys }
  filter :response_status
  filter :sync_run_id
  filter :user_id
  filter :created_at

  index download_links: false do
    id_column
    column :created_at
    column :provider
    column :category
    column :http_method
    column(:path) { |log| Pharmapoint::Logging::DisplayMasker.text(log.path) }
    column :response_status
    column :outcome
    column :attempt
    column :duration_ms
    actions
  end

  show do
    json = lambda do |value|
      next span(t('admin.request_logs.empty')) if value.nil? || value == {}

      details do
        summary t('admin.request_logs.expand')
        pre JSON.pretty_generate(value)
      end
    end

    attributes_table do
      row :id
      row :created_at
      row :provider
      row :category
      row :http_method
      row(:path) { |log| Pharmapoint::Logging::DisplayMasker.text(log.path) }
      row(:query) { |log| json.call(Pharmapoint::Logging::DisplayMasker.query(log.query)) }
      row :response_status
      row :outcome
      row :attempt
      row :duration_ms
      row :error_class
      row :sync_run
      row :user_id
      row(:request_headers) { |log| json.call(Pharmapoint::Logging::DisplayMasker.headers(log.request_headers)) }
      row(:request_body) { |log| json.call(Pharmapoint::Logging::DisplayMasker.body(log.request_body)) }
      row(:response_headers) { |log| json.call(Pharmapoint::Logging::DisplayMasker.headers(log.response_headers)) }
      row(:response_body) { |log| json.call(Pharmapoint::Logging::DisplayMasker.body(log.response_body)) }
    end
  end
end
