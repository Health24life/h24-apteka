# frozen_string_literal: true

FactoryBot.define do
  factory :sync_run do
    provider
    kind { 'drugstores' }
    status { 'running' }
    started_at { Time.current }

    trait :succeeded do
      status { 'succeeded' }
      finished_at { started_at + 1.minute }
    end

    trait :failed do
      status { 'failed' }
      finished_at { started_at + 1.minute }
      error_message { 'boom' }
    end
  end
end

# == Schema Information
#
# Table name: sync_runs
#
#  id              :bigint           not null, primary key
#  error_message   :text
#  failed_count    :integer          default(0), not null
#  finished_at     :datetime
#  kind            :string           not null
#  processed_count :integer          default(0), not null
#  progress        :jsonb            not null
#  started_at      :datetime         not null
#  status          :string           default("running"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  provider_id     :bigint           not null
#
# Indexes
#
#  index_sync_runs_on_provider_id_and_kind_and_started_at  (provider_id,kind,started_at)
#
# Foreign Keys
#
#  fk_rails_...  (provider_id => providers.id)
#
# Check Constraints
#
#  sync_runs_status_check  (status::text = ANY (ARRAY['running'::character varying, 'succeeded'::character varying, 'completed_with_failures'::character varying, 'failed'::character varying]::text[]))
#
