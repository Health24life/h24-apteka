# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::PullRunRetention do
  let(:provider) { create(:provider) }

  def pull_run(started_at) = create(:sync_run, :succeeded, provider:, started_at:, progress: { 'mode' => 'pull' })

  it 'removes the fetches older than the period', :aggregate_failures do
    pull_run(91.days.ago)
    fresh = pull_run(89.days.ago)

    expect(described_class.call).to eq(1)
    expect(SyncRun.all).to contain_exactly(fresh)
  end

  it 'removes the failures of a fetch with it' do
    create(:sync_run_failure, sync_run: pull_run(91.days.ago))

    expect { described_class.call }.to change(SyncRun::Failure, :count).from(1).to(0)
  end

  it 'keeps the recurring runs whatever their age', :aggregate_failures do
    full = create(:sync_run, :succeeded, provider:, started_at: 200.days.ago, progress: { 'mode' => 'full' })
    legacy = create(:sync_run, :succeeded, provider:, started_at: 200.days.ago)

    described_class.call

    expect(SyncRun.all).to contain_exactly(full, legacy)
  end

  it 'applies the period the configuration gives' do
    pull_run(10.days.ago)

    expect { described_class.call(config: pharmapoint_config(pull_run_retention: 7.days)) }
      .to change(SyncRun, :count).by(-1)
  end

  it 'removes more than a batch' do
    stub_const("#{described_class}::BATCH", 2)
    Array.new(3) { pull_run(100.days.ago) }

    expect(described_class.call).to eq(3)
  end
end
