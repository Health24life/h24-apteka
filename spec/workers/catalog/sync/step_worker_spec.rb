# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::StepWorker do
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:run) { SyncRun.order(:id).last }

  def sync(kind) = run_jobs { Catalog::Sync::StartWorker.perform_async(kind) }

  def stub_groups_page(page, fixture: 'goods_group_search', **answer)
    stub_pharmapoint('goods-group/search', fixture:, query: { page: page.to_s, per_page: '2' }, **answer)
  end

  # Answers the first page with the fixture groups changed by the block.
  def stub_first_page_changed
    body = JSON.parse(pharmapoint_fixture('goods_group_search'))
    yield body['data']
    stub_groups_page(1, body: body.to_json)
  end

  def empty_page(page) = { data: [], meta: { page:, per_page: 2, total: 5 } }.to_json

  before { use_pharmapoint_config(goods_groups_per_page: 2) }

  context 'with the dictionaries' do
    before { stub_pharmapoint('dictionaries', fixture: 'dictionaries') }

    it 'imports every dictionary and closes the run as succeeded', :aggregate_failures do
      sync('dictionaries')

      expect(run).to have_attributes(kind: 'dictionaries', status: 'succeeded', processed_count: 12, failed_count: 0)
      expect(Catalog::GoodsForm.pluck(:name)).to contain_exactly({ 'uk' => 'Аерозоль' }, { 'uk' => 'Таблетки' })
      expect(Catalog::DrugstoreBrand.pluck(:name)).to contain_exactly('Аптеки ТАС', 'Подорожник')
    end

    it 'does nothing new when it is run again', :aggregate_failures do
      2.times { sync('dictionaries') }

      expect(Catalog::GoodsForm.count).to eq(2)
      expect(ProviderLink.where(linkable_type: 'Catalog::GoodsForm').count).to eq(2)
    end

    it 'fails the run without a request when the key is missing', :aggregate_failures do
      use_pharmapoint_config(api_key: nil)

      sync('dictionaries')

      expect(run).to have_attributes(status: 'failed', error_message: /API_KEY/)
      expect(WebMock).not_to have_requested(:get, /partner.test/)
    end

    it 'fails the run and leaves earlier data when the provider refuses', :aggregate_failures do
      create(:catalog_goods_form, name_uk: 'Старий')
      stub_pharmapoint('dictionaries', body: '{"message":"no"}', status: 404)

      sync('dictionaries')

      expect(run).to have_attributes(status: 'failed')
      expect(Catalog::GoodsForm.count).to eq(1)
    end
  end

  context 'with the category tree' do
    before { stub_pharmapoint('category/tree', fixture: 'category_tree') }

    it 'saves every level with the parent and the depth', :aggregate_failures do
      sync('categories')

      leaf = Catalog::Category.find_linked(provider, '980')
      expect(run).to have_attributes(status: 'succeeded', processed_count: 5)
      expect(leaf).to have_attributes(depth: 3, parent: Catalog::Category.find_linked(provider, '970'))
    end

    describe 'when a branch moves to another parent' do
      let(:leaf) { Catalog::Category.find_linked(provider, '980') }
      let!(:slug_before) do
        sync('categories')
        leaf.slug
      end

      before do
        moved = JSON.parse(pharmapoint_fixture('category_tree'))
        moved['data'] = [ moved['data'].last, moved['data'].first['children'].first ]
        stub_pharmapoint('category/tree', body: moved.to_json)
        sync('categories')
      end

      it 'updates the depth of its descendants' do
        expect(leaf.reload.depth).to eq(2)
      end

      it 'keeps the address of the category' do
        expect(leaf.reload.slug).to eq(slug_before)
      end
    end
  end

  context 'with goods groups' do
    before do
      stub_pharmapoint('dictionaries', fixture: 'dictionaries')
      stub_groups_page(1)
      stub_groups_page(2, body: empty_page(2))
      stub_groups_page(3, body: empty_page(3))
      sync('dictionaries')
    end

    it 'imports the pages, the group with its SKU and the instruction sections', :aggregate_failures do
      sync('goods_groups')

      goods = Catalog::Goods.find_linked(provider, '1795034')
      expect(run).to have_attributes(kind: 'goods_groups', status: 'succeeded', failed_count: 0)
      expect(goods).to have_attributes(morion_code: '470684', pack_quantity_in_pack: 50)
      expect(goods.instruction_sections.pluck(:code)).to eq(%w[sklad pokazannia protypokazannia])
    end

    it 'writes one log entry per page request, linked to the run', :aggregate_failures do
      sync('goods_groups')

      logs = ProviderRequestLog.where(path: '/api/goods-group/search')
      expect(logs.pluck(:outcome, :sync_run_id, :user_id).uniq).to eq([ [ 'success', run.id, nil ] ])
      expect(logs.count).to eq(3)
    end

    it 'does not copy price, stock or VAT into the catalog' do
      sync('goods_groups')

      expect(Catalog::Goods.column_names).not_to include('online_price', 'drugstore_price', 'quantity', 'nds')
    end

    it 'stores the same data when the pass is repeated' do
      sync('goods_groups')

      expect { sync('goods_groups') }.not_to(change { [ Catalog::Goods.count, Catalog::GoodsGroup.count ] })
    end

    describe 'when one SKU names a dictionary entry that is not there' do
      before do
        stub_first_page_changed { it.first['release_forms'].last['form_id'] = 999_999 }
        sync('goods_groups')
      end

      it 'logs that SKU and closes the run with failures', :aggregate_failures do
        expect(run).to have_attributes(status: 'completed_with_failures', failed_count: 1)
        expect(run.failures.sole).to have_attributes(entity_type: 'Catalog::Goods', external_id: '1795035',
                                                     error_class: 'Catalog::Sync::MissingReference')
      end

      it 'saves the other SKU and the groups' do
        expect(Catalog::Goods.count).to eq(2)
      end
    end

    describe 'when the provider refuses a page' do
      before do
        stub_groups_page(2, body: '{"message":"no"}', status: 404)
        sync('goods_groups')
      end

      it 'ends partial and writes the page to the journal', :aggregate_failures do
        expect(run).to have_attributes(status: 'completed_with_failures', progress: include('partial' => true))
        expect(run.failures.pluck(:entity_type, :external_id)).to include(%w[page 2])
      end

      it 'goes on to the next page' do
        expect(WebMock).to have_requested(:get, pharmapoint_url('goods-group/search'))
          .with(query: { page: '3', per_page: '2' })
      end
    end
  end

  context 'with withdrawal' do
    let(:group) { Catalog::GoodsGroup.find_linked(provider, '122c4abff4ae26d0068e7b4cfce236a6') }

    before do
      stub_pharmapoint('dictionaries', fixture: 'dictionaries')
      stub_groups_page(1)
      stub_groups_page(2, body: empty_page(2))
      stub_groups_page(3, body: empty_page(3))
      sync('dictionaries')
      sync('goods_groups')
    end

    def drop_second_group
      body = JSON.parse(pharmapoint_fixture('goods_group_search'))
      body['data'].pop
      stub_groups_page(1, body: body.to_json)
    end

    it 'marks the group the full pass no longer sees as withdrawn, and keeps it', :aggregate_failures do
      drop_second_group

      sync('goods_groups')

      expect(group.reload).to have_attributes(withdrawn: true)
      expect(Catalog::Goods.find_linked(provider, '2001001').withdrawn).to be(true)
    end

    describe 'when the group shows up again' do
      before do
        drop_second_group
        sync('goods_groups')
        stub_groups_page(1)
        sync('goods_groups')
      end

      it 'brings the group back' do
        expect(group.reload.withdrawn).to be(false)
      end

      it 'brings its SKU back' do
        expect(Catalog::Goods.find_linked(provider, '2001001').withdrawn).to be(false)
      end
    end

    it 'withdraws nothing when a page was lost' do
      drop_second_group
      stub_groups_page(2, body: '{"message":"no"}', status: 404)

      sync('goods_groups')

      expect(group.reload.withdrawn).to be(false)
    end

    describe 'when a group fails in the very pass' do
      before do
        stub_first_page_changed { it.last['goods_producer'] = { 'id' => 5001, 'name' => nil } }
        sync('goods_groups')
      end

      it 'writes it to the journal' do
        expect(run.failures.pluck(:entity_type, :external_id))
          .to include([ 'Catalog::GoodsGroup', '122c4abff4ae26d0068e7b4cfce236a6' ])
      end

      it 'leaves it on the shelf instead of withdrawing it' do
        expect(group.reload.withdrawn).to be(false)
      end
    end

    it 'does not touch the flag an operator set' do
      group.update!(hidden: true)

      sync('goods_groups')

      expect(group.reload.hidden).to be(true)
    end
  end

  it 'does not start a second run of the kind while the first one is running' do
    create(:sync_run, provider:, kind: 'dictionaries', status: 'running', progress: { 'mode' => 'full' })

    expect { Catalog::Sync::StartWorker.new.perform('dictionaries') }.not_to change(SyncRun, :count)
  end

  it 'closes a run that hung and starts a new one', :aggregate_failures do
    stub_pharmapoint('dictionaries', fixture: 'dictionaries')
    hung = create(:sync_run, provider:, kind: 'dictionaries', status: 'running', started_at: 1.day.ago)

    sync('dictionaries')

    expect(hung.reload).to have_attributes(status: 'failed')
    expect(run).to have_attributes(status: 'succeeded')
  end

  describe 'when the provider does not answer in time' do
    it 'raises, so that Sidekiq tries the step again', :aggregate_failures do
      stub_pharmapoint('dictionaries', body: 'down', status: 503)
      Catalog::Sync::StartWorker.new.perform('dictionaries')

      expect { described_class.new.perform(run.id, nil) }.to raise_error(Pharmapoint::TransientError)
      expect(run.reload.status).to eq('running')
    end

    it 'writes the lost step to the journal and goes on once the retries are used up', :aggregate_failures do
      stub_pharmapoint('dictionaries', body: 'down', status: 503)
      Catalog::Sync::StartWorker.new.perform('dictionaries')

      described_class.sidekiq_retries_exhausted_block.call({ 'args' => [ run.id, nil ] }, Pharmapoint::TransientError.new('503'))

      expect(run.reload).to have_attributes(status: 'failed')
      expect(run.failures.sole).to have_attributes(entity_type: 'page', external_id: 'all')
    end

    it 'queues the same step again for when the limit is back, instead of using a retry', :aggregate_failures do
      stub_pharmapoint('dictionaries', body: '{}', status: 429, headers: { 'Retry-After' => '30' })
      Catalog::Sync::StartWorker.new.perform('dictionaries')

      described_class.new.perform(run.id, nil)

      expect(described_class.jobs.pluck('args')).to include([ run.id, nil ])
      expect(described_class.jobs.last['at']).to be_within(5).of(30.seconds.from_now.to_f)
    end
  end
end
