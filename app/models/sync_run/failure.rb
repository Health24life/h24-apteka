# frozen_string_literal: true

class SyncRun::Failure < ApplicationRecord
  belongs_to :sync_run, inverse_of: :failures, counter_cache: :failed_count

  validates :entity_type, :external_id, :error_class, presence: true
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
