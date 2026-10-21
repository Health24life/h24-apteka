# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Search do
  subject(:search) { described_class.new(provider:, user_id: 7, config:) }

  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:config) { pharmapoint_config }
  let(:location) { Catalog::Search::Location.new(latitude: 50.45, longitude: 30.52, radius: 25_000) }
  let(:query) { Catalog::Search::Query.new(text: 'спазмалгон', page: 1, location:) }
  let(:url) { pharmapoint_url('goods-group/search') }

  def stub_search(**answer)
    stub = stub_request(:get, url).with(query: hash_including(query: 'спазмалгон'))
    stub.to_return(pharmapoint_answer(nil, **answer))
  end

  def call(time_left: 4.0) = search.call(query, time_left:)

  describe 'an answer' do
    before { stub_search(body: pharmapoint_fixture('goods_group_search_by_query')) }

    it 'turns every release form of a group into a row of its own', :aggregate_failures do
      page = call

      expect(page.hits.map { [ it.group_external_id, it.external_id ] }).to eq(
        [
          %w[a060d7776d3d256af22378e018bea336 1795034],
          %w[a060d7776d3d256af22378e018bea336 1795035],
          %w[a060d7776d3d256af22378e018bea336 1795036],
          %w[122c4abff4ae26d0068e7b4cfce236a6 2001001]
        ]
      )
      expect(page.hits.map(&:pack).pluck(:quantity_in_pack)).to eq([ 50, 20, 10, 10 ])
    end

    it "keeps the static card only, with the code of the producer's country", :aggregate_failures do
      hit = call.hits.first

      expect(hit).to have_attributes(
        provider: 'pharmapoint',
        name: 'Спазмалгон табл. №50(10х5)',
        trade_name: 'Спазмалгон',
        producer_name: 'Balkanpharma',
        producer_country_code: 'BG',
        group_name: 'Спазмалгон табл. №50(10х5)',
        ready: false,
        id: nil,
        slug: nil
      )
      expect(hit.to_h.keys).not_to include(:online_price, :quantity, :nds, :image_paths)
    end

    it 'tells the pages of goods groups the provider has, and keeps the records for the catalog', :aggregate_failures do
      page = call

      expect(page).to have_attributes(per_page: 20, total_groups: 2, has_more: false)
      expect(page.records.pluck('id')).to eq(%w[a060d7776d3d256af22378e018bea336 122c4abff4ae26d0068e7b4cfce236a6])
    end

    it 'asks around the place of the query, with the page size of the search' do
      call

      expect(
        a_request(:get, url).with(
          query: {
            query: 'спазмалгон',
            page: '1',
            per_page: '20',
            latitude: '50.45',
            longitude: '30.52',
            radius: '25000'
          }
        )
      ).to have_been_requested
    end
  end

  describe 'a failure' do
    it 'is unavailable when the provider is late' do
      stub_request(:get, url).with(query: hash_including({})).to_timeout

      expect(call).to have_attributes(provider: 'pharmapoint', reason: :unavailable)
    end

    it 'is unavailable on a server error' do
      stub_search(body: 'Bad gateway', status: 502)

      expect(call.reason).to eq(:unavailable)
    end

    it 'is a limit refusal with the wait the provider asked for', :aggregate_failures do
      stub_search(body: '{}', status: 429, headers: { 'Retry-After' => '12' })

      expect(call).to have_attributes(reason: :rate_limited, retry_after: 12)
    end

    it 'is a limit refusal once the share of the search is spent, with no call', :aggregate_failures do
      stub = stub_search(body: pharmapoint_fixture('goods_group_search_by_query'))
      limited = described_class.new(provider:, config: pharmapoint_config(search: { rate_limit_per_minute: 1 }))
      limited.call(query, time_left: 4.0)

      expect(limited.call(query, time_left: 4.0).reason).to eq(:rate_limited)
      expect(stub).to have_been_requested.once
    end

    it 'is unavailable and reported on a refusal', :aggregate_failures do
      allow(Rails.error).to receive(:report)
      stub_search(body: '{"message": "forbidden"}', status: 403)

      expect(call.reason).to eq(:unavailable)
      expect(Rails.error).to have_received(:report).with(instance_of(Pharmapoint::PermanentError), any_args)
    end

    it 'is unavailable and reported on a body that cannot be read', :aggregate_failures do
      allow(Rails.error).to receive(:report)
      stub_search(body: 'not json')

      expect(call.reason).to eq(:unavailable)
      expect(Rails.error).to have_received(:report).with(instance_of(Pharmapoint::InvalidResponse), any_args)
    end

    it 'is unavailable without a key, with no call and nothing reported', :aggregate_failures do
      allow(Rails.error).to receive(:report)
      keyless = described_class.new(provider:, config: pharmapoint_config(connection: { api_key: '' }))

      expect(keyless.call(query, time_left: 4.0).reason).to eq(:unavailable)
      expect(Rails.error).not_to have_received(:report)
      expect(a_request(:get, url).with(query: hash_including({}))).not_to have_been_requested
    end

    it 'is unavailable when the limiter cannot reach Redis' do
      limiter = instance_double(Pharmapoint::RateLimiter)
      allow(limiter).to receive(:guard!).and_raise(RedisClient::CannotConnectError)
      allow(limiter).to receive(:share_left).and_return(nil)
      allow(Rails.error).to receive(:report)

      expect(described_class.new(provider:, config:, rate_limiter: limiter).call(query, time_left: 4.0).reason)
        .to eq(:unavailable)
    end

    it 'is unavailable with no call when too little of the request is left to connect', :aggregate_failures do
      expect(call(time_left: 0.5).reason).to eq(:unavailable)
      expect(a_request(:get, url).with(query: hash_including({}))).not_to have_been_requested
    end
  end

  it 'cuts the read timeout to what is left of the request' do
    client = instance_double(Pharmapoint::Client)
    allow(Pharmapoint::Client).to receive(:new).and_return(client)
    allow(client).to receive(:search_goods_groups).and_raise(Pharmapoint::TransientError, 'late')

    call(time_left: 1.5)

    expect(client).to have_received(:search_goods_groups).with(hash_including(read_timeout: 1.5))
  end
end
