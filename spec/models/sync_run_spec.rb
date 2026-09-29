# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncRun do
  subject(:run) { build(:sync_run) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:provider) }
  it { is_expected.to validate_presence_of(:started_at) }
  it { is_expected.to validate_numericality_of(:processed_count).only_integer.is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:failed_count).only_integer.is_greater_than_or_equal_to(0) }

  it 'is valid while running without a finish time' do
    expect(build(:sync_run, status: 'running', finished_at: nil)).to be_valid
  end

  it 'requires a finish time once the run is over', :aggregate_failures do
    %w[succeeded completed_with_failures failed].each do |status|
      expect(build(:sync_run, status:, finished_at: nil)).not_to be_valid
    end
  end

  it 'refuses a finish time before the start' do
    run = build(:sync_run, :succeeded, started_at: Time.zone.parse('2026-09-29 12:00'),
                                       finished_at: Time.zone.parse('2026-09-29 11:00'))

    expect(run).not_to be_valid
  end

  it 'accepts only known kinds and statuses', :aggregate_failures do
    expect(build(:sync_run, kind: 'drugstores')).to be_valid
    expect(build(:sync_run, kind: 'orders')).not_to be_valid
    expect(build(:sync_run, status: 'paused')).not_to be_valid
  end

  it 'removes its failures together with itself' do
    run = create(:sync_run)
    create(:sync_run_failure, sync_run: run)

    expect { run.destroy }.to change(SyncRun::Failure, :count).by(-1)
  end

  describe '.last_successful' do
    let(:provider) { create(:provider) }

    def finished_run(days_ago, **attrs)
      create(:sync_run, :succeeded, started_at: days_ago.days.ago, finished_at: days_ago.days.ago + 1.minute, **attrs)
    end

    it 'returns the latest finished run of the same provider and kind' do
      finished_run(3, provider:)
      latest = finished_run(1, provider:)
      finished_run(0, provider:, kind: 'categories')
      finished_run(0)

      expect(described_class.last_successful(provider, 'drugstores')).to eq(latest)
    end

    it 'counts a run that finished with failures as successful' do
      run = create(:sync_run, provider:, kind: 'goods_groups', status: 'completed_with_failures',
                              started_at: 1.hour.ago, finished_at: 30.minutes.ago)

      expect(described_class.last_successful(provider, 'goods_groups')).to eq(run)
    end

    it 'ignores running and failed runs', :aggregate_failures do
      create(:sync_run, provider:, kind: 'drugstores')
      create(:sync_run, :failed, provider:, kind: 'drugstores')

      expect(described_class.last_successful(provider, 'drugstores')).to be_nil
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
