# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::PullWorker do
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:group_id) { 'a060d7776d3d256af22378e018bea336' }
  let(:run) { SyncRun.last }

  def pull(type = :goods_group, id = group_id, **) = run_jobs { Catalog::Sync::Pull.enqueue(type, id, **) }

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

    expect(run).to have_attributes(kind: 'goods_groups', status: 'succeeded', progress: { 'mode' => 'pull' })
    expect(Catalog::Goods.find_linked(provider, '1795034')).to be_present
  end

  it 'keeps the fetch out of the runs the catalog counts', :aggregate_failures do
    pull

    expect(SyncRun.last_successful(provider, 'goods_groups')).to be_nil
    expect(SyncRun.excluding_pulls.where(kind: 'goods_groups')).to be_empty
  end

  it 'links the log entries to the user and to the run', :aggregate_failures do
    pull(user_id: 7)

    log = ProviderRequestLog.where(path: '/api/goods-group/get-by-id').sole
    expect(log).to have_attributes(user_id: 7, sync_run_id: run.id, category: 'refresh')
  end

  it 'fetches a drugstore from its own record', :aggregate_failures do
    stub_pharmapoint('drugstore/38628', fixture: 'drugstore')

    pull(:drugstore, '38628')

    expect(Catalog::Drugstore.find_linked(provider, '38628')).to have_attributes(ext_drugstore_id: '2369',
                                                                                 incomplete: false)
  end

  describe 'when the provider does not give the record' do
    it 'writes the failure to the journal and leaves the user answer alone', :aggregate_failures do
      stub_pharmapoint('goods-group/get-by-id', body: '{"message":"no such group"}', status: 404,
                                                query: { id: group_id })

      pull

      expect(run).to have_attributes(status: 'failed')
      expect(Catalog::GoodsGroup.count).to eq(0)
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

    expect(run.failures.sole).to have_attributes(entity_type: 'Catalog::GoodsGroup', external_id: group_id)
    expect(run).to have_attributes(status: 'completed_with_failures')
  end
end
