# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::PullWorker do
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:group_id) { 'a060d7776d3d256af22378e018bea336' }
  let(:run) { SyncRun.last }

  def pull(type = :goods_group, id = group_id, **) = run_jobs { Catalog::Sync::Pulls::Enqueue.call(type, id, **) }

  # Answers the fetch of the group with its fields changed.
  def stub_group_with(changes)
    body = JSON.parse(pharmapoint_fixture('goods_group_get_by_id'))
    body['data'].merge!(changes)
    stub_pharmapoint('goods-group/get-by-id', body: body.to_json, query: { id: group_id })
  end

  before do
    use_pharmapoint_config
    stub_pharmapoint('dictionaries', fixture: 'dictionaries')
    run_jobs { Catalog::Sync::StartWorker.perform_async('dictionaries') }
    stub_pharmapoint('goods-group/get-by-id', fixture: 'goods_group_get_by_id', query: { id: group_id })
  end

  it 'fetches the group and saves it with its SKU through a run of its own', :aggregate_failures do
    pull

    expect(run).to have_attributes(
      kind: 'goods_groups',
      status: 'succeeded',
      progress: { 'mode' => 'pull', 'source' => 'provider' }
    )
    expect(Catalog::Goods.find_linked(provider, '1795034')).to be_present
  end

  it 'keeps the fetch out of the runs the catalog counts', :aggregate_failures do
    pull

    expect(SyncRun.last_successful(provider, 'goods_groups')).to be_nil
    expect(SyncRun.excluding_pulls.where(kind: 'goods_groups')).to be_empty
  end

  it 'links the log entries to the user and to the run', :aggregate_failures do
    pull(user_id: 7)

    log = Provider::RequestLog.where(path: '/api/goods-group/get-by-id').sole
    expect(log).to have_attributes(user_id: 7, sync_run_id: run.id, category: 'refresh')
  end

  it 'fetches a drugstore from its own record', :aggregate_failures do
    stub_pharmapoint('drugstore/38628', fixture: 'drugstore')

    pull(:drugstore, '38628')

    expect(Catalog::Drugstore.find_linked(provider, '38628')).to have_attributes(
      ext_drugstore_id: '2369',
      incomplete: false
    )
  end

  describe 'when the provider does not give the record' do
    it 'writes the failure to the journal and leaves the user answer alone', :aggregate_failures do
      stub_pharmapoint(
        'goods-group/get-by-id',
        body: '{"message":"no such group"}',
        status: 404,
        query: { id: group_id }
      )

      pull

      expect(run).to have_attributes(status: 'failed')
      expect(Catalog::Goods::Group.count).to eq(0)
    end

    it 'raises on a transient failure, so that Sidekiq tries again', :aggregate_failures do
      stub_pharmapoint('goods-group/get-by-id', body: 'down', status: 503, query: { id: group_id })

      expect { described_class.new.perform('goods_group', group_id, nil) }.to raise_error(Pharmapoint::TransientError)
      expect(run).to have_attributes(status: 'failed', error_message: /503/)
    end

    it 'waits as long as the provider asks when its limit is used up' do
      error = Pharmapoint::RateLimited.new(42)

      expect(described_class.sidekiq_retry_in_block.call(0, error)).to eq(42)
    end
  end

  it 'logs a record that cannot be saved without failing the worker', :aggregate_failures do
    stub_group_with('goods_producer' => { 'id' => 1, 'name' => nil })
    pull

    expect(run.failures.sole).to have_attributes(entity_type: 'Catalog::Goods::Group', external_id: group_id)
    expect(run).to have_attributes(status: 'completed_with_failures')
  end

  describe 'a group the live search stashed' do
    let(:stash_key) do
      Catalog::Sync::Pulls::Stash.write(
        provider:,
        records: [ complete_goods_group('goods_group_get_by_id') ]
      ).fetch(group_id)
    end

    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    def perform(key = stash_key) = described_class.new.perform('goods_group', group_id, 7, provider.id, key)

    it 'is saved from the stash without asking the provider', :aggregate_failures do
      perform

      expect(Catalog::Goods.find_linked(provider, '1795034')).to be_present
      expect(run).to have_attributes(status: 'succeeded', progress: { 'mode' => 'pull', 'source' => 'stash' })
      expect(WebMock).not_to have_requested(:get, /get-by-id/)
    end

    it 'is saved from the stash even when the request limit is used up', :aggregate_failures do
      Pharmapoint::RateLimiter.new.block!(60)

      expect { perform }.not_to raise_error
      expect(run).to have_attributes(status: 'succeeded')
    end

    it 'is fetched from the provider once the stash has lost it', :aggregate_failures do
      key = stash_key
      Rails.cache.clear
      perform(key)

      expect(run).to have_attributes(status: 'succeeded', progress: { 'mode' => 'pull', 'source' => 'provider' })
      expect(WebMock).to have_requested(:get, /get-by-id/).once
    end
  end

  describe 'when the request limit is used up' do
    before { Pharmapoint::RateLimiter.new.block!(42) }

    it 'puts the fetch off without a failed run when another worker spends the limit after the check',
       :aggregate_failures do
      allow(Pharmapoint::RateLimiter).to receive(:new).and_wrap_original do |original, **options|
        original.call(**options).tap { allow(it).to receive(:wait_time).and_return(0) }
      end

      expect { described_class.new.perform('goods_group', group_id, nil, provider.id) }
        .to raise_error(Pharmapoint::RateLimited)
      expect(SyncRun.where(progress: { 'mode' => 'pull' })).to be_empty
    end

    it 'puts the fetch off without a failed run in the journal', :aggregate_failures do
      expect { described_class.new.perform('goods_group', group_id, nil, provider.id) }
        .to raise_error(Pharmapoint::RateLimited) { expect(it.retry_after).to be_between(41, 42) }
      expect(SyncRun.where(status: 'failed')).to be_empty
      expect(WebMock).not_to have_requested(:get, /get-by-id/)
    end
  end

  it 'fetches a job queued before providers were told apart from the default provider', :aggregate_failures do
    described_class.new.perform('goods_group', group_id, nil)

    expect(run).to have_attributes(provider_id: provider.id, status: 'succeeded')
  end

  it 'reports a job of a disabled provider and opens no run', :aggregate_failures do
    provider.update!(active: false)
    allow(Rails.error).to receive(:report)

    described_class.new.perform('goods_group', group_id, nil, provider.id)

    expect(Rails.error).to have_received(:report)
    expect(SyncRun.where(progress: { 'mode' => 'pull' })).to be_empty
  end

  describe 'a lock' do
    it 'holds the same record of the same provider once while it is fetched', :aggregate_failures do
      results = with_unique_jobs do
        [ 7, 8 ].map { described_class.perform_async('goods_group', group_id, it, provider.id, 'key') }
      end

      expect(results.compact.size).to eq(1)
    end

    it 'does not hold the same id of another provider' do
      results = with_unique_jobs do
        [ provider.id, provider.id + 1 ].map { described_class.perform_async('goods_group', group_id, nil, it) }
      end

      expect(results.compact.size).to eq(2)
    end

    it 'outlasts every retry' do
      waits = (0...described_class::RETRIES).sum { described_class::BACKOFF.call(it) }

      expect(described_class::LOCK_TTL).to be > waits
    end
  end

  describe 'after a failure for good' do
    def paused? = Catalog::Sync::Pulls::Cooldown.paused(provider.id, :goods_group, [ group_id ]).include?(group_id)

    it 'pauses a record the provider would not give' do
      stub_pharmapoint('goods-group/get-by-id', body: '{}', status: 404, query: { id: group_id })
      described_class.new.perform('goods_group', group_id, nil, provider.id)

      expect(paused?).to be(true)
    end

    it 'pauses a record that could not be saved' do
      stub_group_with('goods_producer' => { 'id' => 1, 'name' => nil })
      described_class.new.perform('goods_group', group_id, nil, provider.id)

      expect(paused?).to be(true)
    end

    it 'pauses a record whose retries are spent' do
      job = { 'args' => [ 'goods_group', group_id, nil, provider.id, nil ] }
      described_class.sidekiq_retries_exhausted_block.call(job, Pharmapoint::TransientError.new('down'))

      expect(paused?).to be(true)
    end

    it 'does not pause a record whose retries were spent waiting for the request limit' do
      job = { 'args' => [ 'goods_group', group_id, nil, provider.id, nil ] }
      described_class.sidekiq_retries_exhausted_block.call(job, Pharmapoint::RateLimited.new(60))

      expect(paused?).to be(false)
    end

    it 'does not pause a record that could not be fetched for a missing setting', :aggregate_failures do
      use_pharmapoint_config(connection: { api_key: nil })
      described_class.new.perform('goods_group', group_id, nil, provider.id)

      expect(run).to have_attributes(status: 'failed', error_message: /PHARMAPOINT_API_KEY/)
      expect(paused?).to be(false)
    end

    it 'does not pause a record that was saved' do
      described_class.new.perform('goods_group', group_id, nil, provider.id)

      expect(paused?).to be(false)
    end
  end
end
