# frozen_string_literal: true

ActiveAdmin.register SyncRun do
  menu parent: 'sync', priority: 1

  actions :index, :show
  config.batch_actions = false
  config.comments = false
  config.sort_order = 'started_at_desc'

  includes :provider

  filter :kind, as: :select, collection: proc { SyncRun.kinds.keys.map { [ t("admin.sync_runs.kinds.#{it}"), it ] } }
  filter :mode_eq, as: :select, label: proc { SyncRun.human_attribute_name(:mode) },
                   collection: proc { %w[full pull].map { [ t("admin.sync_runs.mode.#{it}"), it ] } }
  filter :status, as: :select, collection: proc { SyncRun.statuses.keys }
  filter :started_at

  index download_links: false do
    id_column
    column :provider
    column(:kind) { |run| t("admin.sync_runs.kinds.#{run.kind}") }
    column(:mode) { |run| t("admin.sync_runs.mode.#{run.progress.fetch('mode', 'full')}") }
    column :status
    column :started_at
    column :finished_at
    column :processed_count
    column :failed_count
    actions
  end

  show do
    attributes_table do
      row :id
      row :provider
      row(:kind) { |run| t("admin.sync_runs.kinds.#{run.kind}") }
      row(:mode) { |run| t("admin.sync_runs.mode.#{run.progress.fetch('mode', 'full')}") }
      row :status
      row :started_at
      row :finished_at
      row :processed_count
      row :failed_count
      row(:progress) { |run| pre JSON.pretty_generate(run.progress) }
      row :error_message
    end

    panel t('admin.sync_runs.request_logs') do
      para link_to(t('admin.sync_runs.open_request_logs'),
                   admin_provider_request_logs_path(q: { sync_run_id_eq: resource.id }))
    end

    panel t('admin.sync_runs.failures') do
      masker = Pharmapoint::DisplayMasker
      table_for resource.failures.order(:id) do
        column(SyncRun::Failure.human_attribute_name(:created_at)) { |failure| l(failure.created_at, format: :long) }
        column(SyncRun::Failure.human_attribute_name(:entity_type), &:entity_type)
        column(SyncRun::Failure.human_attribute_name(:external_id)) { |failure| masker.text(failure.external_id) }
        column(SyncRun::Failure.human_attribute_name(:error_class), &:error_class)
        column(SyncRun::Failure.human_attribute_name(:message)) { |failure| masker.text(failure.message.to_s) }
        column(SyncRun::Failure.human_attribute_name(:payload)) do |failure|
          pre JSON.pretty_generate(masker.body(failure.payload)) unless failure.payload.nil?
        end
      end
    end
  end

  action_item :start, only: :index do
    buttons = SyncRun.kinds.keys.map do |kind|
      label = t('admin.sync_runs.start', kind: t("admin.sync_runs.kinds.#{kind}"))
      if Pharmapoint::Schedule.sync_enabled?(kind)
        button_to label, start_admin_sync_runs_path(kind:), class: 'action-item-button', form: { class: 'inline' }
      else
        tag.span label, class: 'action-item-button opacity-50 cursor-not-allowed', aria: { disabled: true },
                        title: t('admin.sync_runs.disabled_hint')
      end
    end
    safe_join(buttons)
  end

  collection_action :start, method: :post do
    kind = params.require(:kind).to_s
    result = Catalog::Sync::ManualStart.call(kind)
    message = t("admin.sync_runs.#{result}", kind: t("admin.sync_runs.kinds.#{kind}", default: kind))
    redirect_to collection_path, (result == :started ? :notice : :alert) => message
  end
end
