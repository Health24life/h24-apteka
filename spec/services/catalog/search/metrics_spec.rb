# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Search::Metrics do
  let(:group) { Yabeda.apteka_search }
  let(:location) { Catalog::Search::Location.new(latitude: 50.45, longitude: 30.52, radius: 25_000) }
  let(:query) { Catalog::Search::Query.new(text: 'спазмалгон', page: 1, location:) }
  let(:provider) { create(:provider, code: 'pharmapoint') }

  def counted(metric, **tags) = group.public_send(metric).get(tags).to_i

  def failure(reason = :unavailable) = Catalog::Search::Failure.new(provider: 'pharmapoint', reason:, retry_after: 5)

  def page(*hits)
    Catalog::Search::ProviderPage.new(
      provider: 'pharmapoint',
      hits:,
      per_page: 20,
      total_groups: 1,
      has_more: false,
      records: []
    )
  end

  def pull(source, **attributes)
    create(
      :sync_run,
      provider:,
      kind: 'goods_groups',
      status: 'succeeded',
      started_at: 5.minutes.ago,
      finished_at: 4.minutes.ago,
      progress: { 'mode' => 'pull', 'source' => source },
      **attributes
    )
  end

  def result(status, goods: [], failures: [])
    Catalog::Search::Result.new(
      query: 'спазмалгон',
      status:,
      unavailable_providers: [],
      page: 1,
      per_page: 20,
      total_groups: 0,
      has_more: false,
      goods:,
      failures:
    )
  end

  it 'counts every query of the search by its outcome', :aggregate_failures do
    outcomes = {
      'ok' => result('ok', goods: [ :hit ]),
      'empty' => result('ok'),
      'partial' => result('partial', goods: [ :hit ], failures: [ failure ]),
      'unavailable' => result('unavailable', failures: [ failure ]),
      'busy' => result('unavailable', failures: [ failure(:rate_limited) ])
    }

    outcomes.each do |status, counted_result|
      expect { described_class.results([ counted_result ]) }.to change { counted(:requests_total, status:) }.by(1)
    end
  end

  it 'counts every answer of a provider by its outcome', :aggregate_failures do
    hit = Struct.new(:id).new(1)
    {
      'ok' => page(hit),
      'empty' => page,
      'unavailable' => failure,
      'busy' => failure(:rate_limited)
    }.each do |status, answer|
      expect { described_class.answer('pharmapoint', answer) }
        .to change { counted(:provider_answers_total, provider: 'pharmapoint', status:) }.by(1)
    end
  end

  it 'keeps what is left of the share of the search' do
    described_class.share_left('pharmapoint') { 17 }

    expect(counted(:rate_limit_share_left, provider: 'pharmapoint')).to eq(17)
  end

  it 'never lets a failure to count reach the search' do
    allow(Rails.error).to receive(:report)

    expect { described_class.share_left('pharmapoint') { raise Redis::CannotConnectError } }.not_to raise_error
  end

  it 'counts the fetches of the last hour saved from the stash and from the provider' do
    [
      [ 'stash' ],
      [ 'stash' ],
      [ 'provider' ],
      [ 'provider', { started_at: 2.hours.ago } ],
      [ 'provider', { status: 'failed' } ]
    ]
      .each do |source, attributes|
 pull(source, **attributes.to_h)
    end

    described_class.collect_pulls

    expect(%w[stash provider].map { counted(:pulls, provider: 'pharmapoint', source: it) }).to eq([ 2, 1 ])
  end

  describe 'in the search' do
    before do
      allow(Catalog::Sync::Pulls::EnqueueFound).to receive(:call).and_return({})
use_pharmapoint_config
      stub_request(:get, pharmapoint_url('goods-group/search')).with(query: hash_including({}))
        .to_return(pharmapoint_answer('goods_group_search_by_query'))
    end

    def search = Catalog::Search::Run.call([ query ], adapters: [ Pharmapoint::Search.new(provider:) ])

    it 'counts the outcome of a query and the answer of each provider' do
      expect { search }
        .to change { counted(:requests_total, status: 'ok') }.by(1)
        .and change { counted(:provider_answers_total, provider: 'pharmapoint', status: 'ok') }.by(1)
    end

    it "measures the provider's time and keeps what is left of the share", :aggregate_failures do
      allow(group.provider_duration_seconds).to receive(:measure).and_call_original

      search

      expect(group.provider_duration_seconds).to have_received(:measure).with({ provider: 'pharmapoint' }, Float)
      expect(counted(:rate_limit_share_left, provider: 'pharmapoint')).to eq(39)
    end
  end
end
