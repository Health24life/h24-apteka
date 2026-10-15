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

    def link(synced_at) = Provider::Link.create!(provider:, linkable: group, external_id: group_id, synced_at:)

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
      Provider::Link.create!(provider:, linkable: drugstore, external_id: '38628', synced_at: 1.minute.ago)

      expect(described_class.enqueue(:drugstore, '38628')).to eq(:enqueued)
    end
  end

  describe 'a record of a provider asked for by name' do
    it 'carries the provider to the worker' do
      described_class.enqueue(:goods_group, group_id, provider:)

      expect(queued).to eq([ [ 'goods_group', group_id, nil, provider.id ] ])
    end

    it 'is checked against the links of that provider' do
      other = create(:provider, code: 'other')
      Provider::Link.create!(provider:, linkable: create(:catalog_goods_group), external_id: group_id,
                             synced_at: 1.hour.ago)

      expect(described_class.enqueue(:goods_group, group_id, provider: other)).to eq(:enqueued)
    end
  end

  describe '.enqueue_found' do
    let(:record) { complete_goods_group }
    let(:group) { create(:catalog_goods_group) }

    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    def goods_ids = record['release_forms'].pluck('id').map(&:to_s)

    def found(records = [ record ], on: provider)
      described_class.enqueue_found(provider: on, found: records, user_id: 7)
    end

    def link_group(synced_at: 1.hour.ago, **attributes)
      group.update!(attributes) if attributes.any?
      Provider::Link.create!(provider:, linkable: group, external_id: group_id, synced_at:)
    end

    def link_goods(ids = goods_ids)
      ids.each do |id|
        Provider::Link.create!(provider:, linkable: create(:catalog_goods, goods_group: group), external_id: id,
                               synced_at: 1.hour.ago)
      end
    end

    it 'queues a group the catalog lacks with the key of its stashed record', :aggregate_failures do
      expect(found).to eq(group_id => :enqueued)

      stash_key = Catalog::Sync::Stash.key(provider.id, group_id)
      expect(queued).to eq([ [ 'goods_group', group_id, 7, provider.id, stash_key ] ])
      expect(Catalog::Sync::Stash.read(stash_key)).to include('id' => group_id)
    end

    it 'queues a group it cannot stash without a key, so the fetch asks the provider' do
      found([ record.merge('goods_categories' => []) ])

      expect(queued.sole.last).to be_nil
    end

    it 'leaves a fresh group with every SKU alone', :aggregate_failures do
      link_group
      link_goods

      expect(found).to eq(group_id => :present)
      expect(queued).to be_empty
    end

    it 'queues a stale group' do
      link_group(synced_at: 3.days.ago)
      link_goods

      expect(found).to eq(group_id => :enqueued)
    end

    it 'queues a withdrawn group' do
      link_group(withdrawn: true)
      link_goods

      expect(found).to eq(group_id => :enqueued)
    end

    it 'queues a fresh group that brings a SKU the catalog lacks' do
      link_group
      link_goods(goods_ids.first(1))

      expect(found).to eq(group_id => :enqueued)
    end

    it 'leaves a group an operator hid alone', :aggregate_failures do
      link_group(synced_at: 3.days.ago, hidden: true)

      expect(found).to eq(group_id => :hidden)
      expect(queued).to be_empty
    end

    it 'leaves a fresh group alone though one of its SKU is hidden' do
      link_group
      link_goods
      Catalog::Goods.update_all(hidden: true) # rubocop:disable Rails/SkipsModelValidations

      expect(found).to eq(group_id => :present)
    end

    it 'queues a group with the same id at each provider', :aggregate_failures do
      other = create(:provider, code: 'other')

      with_unique_jobs { [ found, found(on: other) ] }

      expect(queued.pluck(3)).to contain_exactly(provider.id, other.id)
    end

    it 'queues a group found twice once while the first fetch has not ended' do
      expect(with_unique_jobs do
 [ found, found ]
      end).to eq([ { group_id => :enqueued }, { group_id => :queued_already } ])
    end

    describe 'after a fetch failed for good' do
      before { described_class.cool_down!(provider.id, :goods_group, group_id, config: pharmapoint_config) }

      it 'does not queue the group during the pause', :aggregate_failures do
        expect(found).to eq(group_id => :cooling_down)
        expect(queued).to be_empty
      end

      it 'queues it again once the pause is over' do
        reset_pharmapoint_redis

        expect(found).to eq(group_id => :enqueued)
      end

      it 'does not hold the same id of another provider' do
        expect(found(on: create(:provider, code: 'other'))).to eq(group_id => :enqueued)
      end
    end

    it 'checks a page in two queries, whatever the number of groups' do
      page = Array.new(5) { |i| record.merge('id' => "group-#{i}") }

      statements = QueryLog.capture { found(page) }

      expect(statements.count { it.start_with?('SELECT') }).to eq(2)
    end

    it 'reports a failure instead of breaking the search', :aggregate_failures do
      allow(Sidekiq).to receive(:redis).and_raise(Redis::CannotConnectError)
      allow(Rails.error).to receive(:report)

      expect(found).to eq({})
      expect(Rails.error).to have_received(:report)
    end

    it 'reports a disabled provider instead of breaking the search', :aggregate_failures do
      provider.update!(active: false)
      allow(Rails.error).to receive(:report)

      expect(found).to eq({})
      expect(Rails.error).to have_received(:report)
    end
  end
end
