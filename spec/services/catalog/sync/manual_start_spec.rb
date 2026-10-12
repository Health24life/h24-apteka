# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::ManualStart do
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:runs) { SyncRun.excluding_pulls.where(provider:) }

  it 'opens a run of a kind the schedule has on and queues its first step', :aggregate_failures do
    expect(described_class.call('drugstores', env: {})).to eq(:started)
    expect(runs.sole).to have_attributes(kind: 'drugstores', status: 'running')
    expect(Catalog::Sync::StepWorker.jobs.size).to eq(1)
  end

  it 'opens no second run of a kind that is running', :aggregate_failures do
    create(:sync_run, provider:, kind: 'drugstores', started_at: 1.minute.ago)

    expect(described_class.call('drugstores', env: {})).to eq(:already_running)
    expect(runs.count).to eq(1)
  end

  it 'opens nothing for a kind the schedule has off', :aggregate_failures do
    expect(described_class.call('goods_groups', env: {})).to eq(:disabled)
    expect(runs).to be_empty
  end

  it 'opens a run of a kind once the schedule turns it on' do
    expect(described_class.call('goods_groups', env: { 'SYNC_CRON_GOODS_GROUPS' => '0 2 * * *' })).to eq(:started)
  end

  it 'opens nothing for a kind the schedule does not know' do
    expect(described_class.call('symptoms', env: {})).to eq(:disabled)
  end
end
