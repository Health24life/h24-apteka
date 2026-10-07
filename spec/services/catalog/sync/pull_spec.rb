# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Pull do
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:group_id) { 'a060d7776d3d256af22378e018bea336' }
  let(:queued) { Catalog::Sync::PullWorker.jobs.pluck('args') }

  before { use_pharmapoint_config }

  it 'queues a goods group the catalog does not have, without waiting for it', :aggregate_failures do
    expect(described_class.enqueue(:goods_group, group_id)).to eq(:enqueued)
    expect(queued).to eq([ [ 'goods_group', group_id, nil ] ])
  end

  it 'passes on the user whose request found the gap' do
    described_class.enqueue(:goods_group, group_id, user_id: 7)

    expect(queued).to eq([ [ 'goods_group', group_id, 7 ] ])
  end

  describe 'a record asked for twice' do
    it 'is queued once while the first fetch has not ended', :aggregate_failures do
      results = with_unique_jobs { Array.new(2) { described_class.enqueue(:goods_group, group_id) } }

      expect(results).to eq(%i[enqueued queued_already])
      expect(queued.size).to eq(1)
    end

    it 'is queued once whoever asks', :aggregate_failures do
      results = with_unique_jobs do
        [ described_class.enqueue(:goods_group, group_id, user_id: 1),
          described_class.enqueue(:goods_group, group_id, user_id: 2) ]
      end

      expect(results).to eq(%i[enqueued queued_already])
    end

    it 'is queued again once the first fetch has ended' do
      allow(Catalog::Sync::PullRunner).to receive(:call)
      with_unique_jobs { described_class.enqueue(:goods_group, group_id) }
      Catalog::Sync::PullWorker.drain

      expect(with_unique_jobs { described_class.enqueue(:goods_group, group_id) }).to eq(:enqueued)
    end

    it 'does not hold two different records against each other' do
      results = with_unique_jobs { [ group_id, 'f' * 32 ].map { described_class.enqueue(:goods_group, it) } }

      expect(results).to eq(%i[enqueued enqueued])
    end
  end

  describe 'a record the catalog already has' do
    let(:group) { create(:catalog_goods_group) }

    def link(synced_at) = ProviderLink.create!(provider:, linkable: group, external_id: group_id, synced_at:)

    it 'is not fetched again while it is fresh', :aggregate_failures do
      link(1.hour.ago)

      expect(described_class.enqueue(:goods_group, group_id)).to eq(:present)
      expect(queued).to be_empty
    end

    it 'is fetched again once it is stale' do
      link(3.days.ago)

      expect(described_class.enqueue(:goods_group, group_id)).to eq(:enqueued)
    end
  end

  describe 'a drugstore the catalog has only in part' do
    let(:drugstore) { create(:catalog_drugstore, incomplete: true) }

    it 'is fetched to be completed even when it is fresh' do
      ProviderLink.create!(provider:, linkable: drugstore, external_id: '38628', synced_at: 1.minute.ago)

      expect(described_class.enqueue(:drugstore, '38628')).to eq(:enqueued)
    end
  end
end
