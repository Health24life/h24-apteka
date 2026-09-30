# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncRun::Failure do
  subject(:failure) { build(:sync_run_failure) }

  it { is_expected.to be_valid }
  it { is_expected.to validate_presence_of(:entity_type) }
  it { is_expected.to validate_presence_of(:external_id) }
  it { is_expected.to validate_presence_of(:error_class) }

  it 'keeps the failed counter of the run in step', :aggregate_failures do
    run = create(:sync_run)

    failure = create(:sync_run_failure, sync_run: run)
    expect(run.reload.failed_count).to eq(1)

    failure.destroy
    expect(run.reload.failed_count).to eq(0)
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
