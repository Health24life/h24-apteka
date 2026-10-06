# frozen_string_literal: true

FactoryBot.define do
  factory :sync_run_failure, class: 'SyncRun::Failure' do
    sync_run
    entity_type { 'Catalog::Drugstore' }
    sequence(:external_id, &:to_s)
    error_class { 'StandardError' }
  end
end

# == Schema Information
#
# Table name: sync_run_failures
#
#  id          :bigint           not null, primary key
#  entity_type :string           not null
#  error_class :string           not null
#  message     :text
#  payload     :jsonb
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  external_id :string           not null
#  sync_run_id :bigint           not null
#
# Indexes
#
#  index_sync_run_failures_on_sync_run_id  (sync_run_id)
#
# Foreign Keys
#
#  fk_rails_...  (sync_run_id => sync_runs.id) ON DELETE => cascade
#
