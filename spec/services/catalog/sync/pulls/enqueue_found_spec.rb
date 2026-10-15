# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Pulls::EnqueueFound do
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:group_id) { 'a060d7776d3d256af22378e018bea336' }
  let(:queued) { Catalog::Sync::PullWorker.jobs.pluck('args') }
  let(:record) { complete_goods_group }
  let(:group) { create(:catalog_goods_group) }

  before do
    use_pharmapoint_config
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  def goods_ids = record['release_forms'].pluck('id').map(&:to_s)

  def found(records = [ record ], on: provider)
    described_class.call(provider: on, found: records, user_id: 7)
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

    stash_key = Catalog::Sync::Pulls::Stash.key(provider.id, group_id)
    expect(queued).to eq([ [ 'goods_group', group_id, 7, provider.id, stash_key ] ])
    expect(Catalog::Sync::Pulls::Stash.read(stash_key)).to include('id' => group_id)
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
    before { Catalog::Sync::Pulls::Cooldown.pause!(provider.id, :goods_group, group_id, config: pharmapoint_config) }

    it 'does not queue the group during the pause', :aggregate_failures do
      expect(found).to eq(group_id => :paused)
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
