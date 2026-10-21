# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Client do
  subject(:client) { build_client }

  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:log) { Provider::RequestLog.last }

  def build_client(config: pharmapoint_config, **) = described_class.new(provider:, config:, **)

  describe 'reading answers' do
    it 'reads a page of goods groups, sending the key and the domain name as headers', :aggregate_failures do
      stub = stub_pharmapoint('goods-group/search', fixture: 'goods_group_search', query: { page: '1', per_page: '2' })

      page = client.goods_groups(page: 1, per_page: 2)

      expect(page.items.size).to eq(2)
      expect(stub.with(headers: { 'API-Key' => 'secret-key', 'Domain-Name' => 'h24.test' })).to have_been_requested
    end

    it 'reads a goods group by id' do
      stub_pharmapoint('goods-group/get-by-id', fixture: 'goods_group_get_by_id', query: { id: 'abc' })

      expect(client.goods_group('abc').external_id).to eq('a060d7776d3d256af22378e018bea336')
    end

    it 'reads the dictionaries and the category tree', :aggregate_failures do
      stub_pharmapoint('dictionaries', fixture: 'dictionaries')
      stub_pharmapoint('category/tree', fixture: 'category_tree')

      expect(client.dictionaries.forms.size).to eq(2)
      expect(client.category_tree.size).to eq(2)
    end

    it 'reads the drugstores around a point' do
      point = Pharmapoint::SearchPoint.new(latitude: 50.45, longitude: 30.52, radius: 1000)
      stub_pharmapoint(
        'drugstore',
        fixture: 'drugstores',
        query: { latitude: '50.45', longitude: '30.52', radius: '1000' }
      )

      expect(client.drugstores(point).size).to eq(2)
    end

    it 'reads a single drugstore' do
      stub_pharmapoint('drugstore/38628', fixture: 'drugstore')

      expect(client.drugstore('38628').outer_id).to eq('2369')
    end
  end

  describe 'request log' do
    before { stub_pharmapoint('dictionaries', fixture: 'dictionaries', headers: { 'X-Ratelimit-Remaining' => '99' }) }

    it 'records the answer: status code, outcome, category and attempt', :aggregate_failures do
      client.dictionaries

      expect(log).to have_attributes(
        http_method: 'GET',
        path: '/api/dictionaries',
        response_status: 200,
        outcome: 'success',
        category: 'refresh',
        attempt: 1,
        error_class: nil
      )
      expect(log).to have_attributes(user_id: nil, sync_run_id: nil)
    end

    it 'records the headers of both sides and the whole body', :aggregate_failures do
      client.dictionaries

      expect(log.response_headers).to include('x-ratelimit-remaining' => '99', 'content-type' => 'application/json')
      expect(log.request_headers).to include('accept' => 'application/json', 'domain-name' => 'h24.test')
      expect(log.response_body.dig('data', 'goods_form').size).to eq(2)
    end

    it 'never stores the key', :aggregate_failures do
      client.dictionaries

      expect(log.request_headers['api-key']).to eq('[masked]')
      expect(log.to_json).not_to include('secret-key')
    end

    it 'links the entry to the user whose action caused the call and to the run' do
      run = create(:sync_run, provider:)
      user = create(:h24_core_user)

      build_client(sync_run: run, user_id: user.id, purpose: :search).dictionaries

      expect(log).to have_attributes(user_id: user.id, sync_run_id: run.id, category: 'search')
    end

    it 'writes the number of the attempt' do
      build_client(attempt: 3).dictionaries

      expect(log.attempt).to eq(3)
    end

    it 'hides the phone of a client in the stored bodies' do
      stub_pharmapoint('drugstore/1', body: '{"data":[{"id":1,"customer_phone_number":"380501112233"}]}')

      client.drugstore('1')

      expect(log.response_body.dig('data', 0, 'customer_phone_number')).to eq('[masked]')
    end

    it 'reports a failure to write the log and still returns the answer', :aggregate_failures do
      allow(Provider::RequestLog).to receive(:new).and_raise(ActiveRecord::StatementInvalid, 'disk full')
      allow(Rails.error).to receive(:report)

      expect(client.dictionaries.forms.size).to eq(2)
      expect(Rails.error).to have_received(:report).with(an_instance_of(ActiveRecord::StatementInvalid), anything)
    end
  end

  describe 'failures' do
    def stub_failure(**) = stub_pharmapoint('dictionaries', **)

    it 'treats a timeout as transient and logs it with no status code', :aggregate_failures do
      stub_request(:get, pharmapoint_url('dictionaries')).to_timeout

      expect { client.dictionaries }.to raise_error(Pharmapoint::TransientError)
      expect(log).to have_attributes(outcome: 'timeout', response_status: nil, response_body: nil, response_headers: {})
    end

    it 'treats a broken connection as transient and logs it', :aggregate_failures do
      stub_request(:get, pharmapoint_url('dictionaries')).to_raise(Faraday::ConnectionFailed.new('refused'))

      expect { client.dictionaries }.to raise_error(Pharmapoint::TransientError)
      expect(log).to have_attributes(outcome: 'connection_error', response_status: nil)
    end

    it 'treats a server error as transient and logs the code and the text of the answer', :aggregate_failures do
      stub_failure(body: 'Bad gateway', status: 502, headers: { 'Content-Type' => 'text/html' })

      expect { client.dictionaries }.to raise_error(Pharmapoint::TransientError, /502/)
      expect(log).to have_attributes(outcome: 'http_error', response_status: 502, response_body: 'Bad gateway')
    end

    it 'treats a refusal as permanent', :aggregate_failures do
      stub_failure(body: '{"message":"no"}', status: 404)

      expect { client.dictionaries }.to raise_error(Pharmapoint::PermanentError) { expect(it.status).to eq(404) }
      expect(log).to have_attributes(outcome: 'http_error', response_status: 404)
    end

    it 'does not put the key into the message of an error', :aggregate_failures do
      stub_failure(body: 'key secret-key rejected', status: 403)

      expect { client.dictionaries }.to raise_error(Pharmapoint::PermanentError) do |error|
        expect(error.message).not_to include('secret-key')
      end
    end

    it 'holds every later call back after the partner says the limit is used up', :aggregate_failures do
      stub_failure(body: '{}', status: 429, headers: { 'Retry-After' => '30' })

      expect { client.dictionaries }.to raise_error(Pharmapoint::RateLimited) { expect(it.retry_after).to eq(30) }
      expect { client.dictionaries }.to raise_error(Pharmapoint::RateLimited)
      expect(WebMock).to have_requested(:get, pharmapoint_url('dictionaries')).once
    end

    it 'sends nothing and logs nothing without a key', :aggregate_failures do
      client = build_client(config: pharmapoint_config(connection: { api_key: nil }))

      expect { client.dictionaries }.to raise_error(Pharmapoint::ConfigurationError)
      expect(WebMock).not_to have_requested(:get, /partner.test/)
      expect(Provider::RequestLog.count).to eq(0)
    end

    it 'does not spend the request limit without a key', :aggregate_failures do
      config = pharmapoint_config(connection: { api_key: nil }, rate_limit: { per_minute: 1 })
      client = build_client(config:)

      expect { client.dictionaries }.to raise_error(Pharmapoint::ConfigurationError)
      expect(Pharmapoint::RateLimiter.new(config:).wait_time).to eq(0)
    end
  end

  describe 'an answer that cannot be read' do
    it 'logs 200 with a body that is not JSON as an invalid response', :aggregate_failures do
      stub_pharmapoint('dictionaries', body: '{"data": ')

      expect { client.dictionaries }.to raise_error(Pharmapoint::InvalidResponse)
      expect(log).to have_attributes(outcome: 'invalid_response', response_status: 200, response_body: '{"data": ')
    end

    it 'logs 200 with a page that is not an answer as an invalid response', :aggregate_failures do
      stub_pharmapoint('dictionaries', body: '<html>maintenance</html>', headers: { 'Content-Type' => 'text/html' })

      expect { client.dictionaries }.to raise_error(Pharmapoint::InvalidResponse)
      expect(log).to have_attributes(outcome: 'invalid_response', response_status: 200)
    end

    it 'logs 200 with JSON that lacks the expected structure as an invalid response', :aggregate_failures do
      stub_pharmapoint('dictionaries', body: '{"hello": 1}')

      expect { client.dictionaries }.to raise_error(Pharmapoint::InvalidResponse)
      expect(log).to have_attributes(outcome: 'invalid_response', response_status: 200)
    end
  end

  describe 'live search' do
    let(:point) { Pharmapoint::SearchPoint.new(latitude: 50.45, longitude: 30.52, radius: 25_000) }
    let(:query) do
      { query: 'спазмалгон', page: '1', per_page: '20', latitude: '50.45', longitude: '30.52', radius: '25000' }
    end

    before { stub_pharmapoint('goods-group/search', fixture: 'goods_group_search_by_query', query:) }

    def search(client = build_client(purpose: :search))
      client.search_goods_groups(query: 'спазмалгон', page: 1, location: point)
    end

    it 'reads the groups found by the text around the point, and keeps their records as the partner gave them',
       :aggregate_failures do
      groups, records = search

      expect(groups.items.map(&:external_id))
        .to eq(%w[a060d7776d3d256af22378e018bea336 122c4abff4ae26d0068e7b4cfce236a6])
      expect(groups).to have_attributes(page: 1, per_page: 20, total: 2)
      expect(records.first).to include('id' => 'a060d7776d3d256af22378e018bea336', 'online_price' => 28.99)
    end

    it 'sends no phone of a client' do
      search

      sent = a_request(:get, pharmapoint_url('goods-group/search')).with(query:) do |request|
        !request.headers.keys.intersect?(%w[Customer-Phone Insurance-Code])
      end
      expect(sent).to have_been_requested
    end

    it 'logs the call as a search of the user' do
      search(build_client(purpose: :search, user_id: 42))

      expect(log).to have_attributes(category: 'search', user_id: 42)
    end

    it 'spends the share of the search, not only the budget of the whole service', :aggregate_failures do
      stub_pharmapoint('dictionaries', fixture: 'dictionaries')
      config = pharmapoint_config(rate_limit: { per_minute: 3 }, search: { rate_limit_per_minute: 1 })
      search(build_client(purpose: :search, config:))

      expect { search(build_client(purpose: :search, config:)) }.to raise_error(Pharmapoint::RateLimited)
      expect { 2.times { build_client(config:).dictionaries } }.not_to raise_error
    end

    it 'treats a timeout of the search as transient' do
      stub_request(:get, pharmapoint_url('goods-group/search')).with(query:).to_timeout

      expect { search }.to raise_error(Pharmapoint::TransientError)
    end
  end

  describe 'live offers of drugstores' do
    let(:lines) { [ Pharmapoint::OrderLine.new(external_id: '1750321', quantity: 2) ] }
    let(:point) { Pharmapoint::SearchPoint.new(latitude: 50.45, longitude: 30.52, radius: 25_000) }

    def stub_offers(path, fixture, with_empty_stock:)
      stub_request(:post, pharmapoint_url(path))
        .with(query: { with_empty_stock: })
        .to_return(pharmapoint_answer(fixture))
    end

    it 'asks around the point for the drugstores with stock, the goods in the body', :aggregate_failures do
      stub = stub_offers('order/get-drugstores-for-order-goods', 'offers_nearby', with_empty_stock: '0')

      offers = build_client(purpose: :booking).offers_nearby(goods: lines, location: point)

      expect(offers.map(&:drugstore_external_id)).to eq(%w[510 552])
      body = { goods: [ { goods_id: '1750321', quantity: 2 } ], latitude: 50.45, longitude: 30.52, radius: 25_000 }
      expect(stub.with(body:, headers: { 'Content-Type' => 'application/json' })).to have_been_requested
    end

    it 'asks one drugstore by its id, also when it has no stock', :aggregate_failures do
      stub = stub_offers('order/get-drugstore-for-order-goods', 'offers_in_drugstore', with_empty_stock: '1')

      offers = build_client.offers_in_drugstore(goods: lines, drugstore_external_id: '32953')

      expect(offers.first.items.first.price).to eq(BigDecimal('162.5'))
      expect(
        stub.with(
          body: {
            goods: [ { goods_id: '1750321', quantity: 2 } ],
            drugstore_id: '32953'
          }
        )
      ).to have_been_requested
    end

    it 'logs the body sent and sends no phone of a client', :aggregate_failures do
      stub_offers('order/get-drugstores-for-order-goods', 'offers_nearby', with_empty_stock: '0')

      build_client(purpose: :booking).offers_nearby(goods: lines, location: point)

      expect(log).to have_attributes(http_method: 'POST', category: 'booking')
      expect(log.request_body).to include('goods' => [ { 'goods_id' => '1750321', 'quantity' => 2 } ])
      expect(log.request_headers.keys).not_to include('customer-phone', 'insurance-code')
    end

    it 'spends the share of the cart', :aggregate_failures do
      stub_offers('order/get-drugstores-for-order-goods', 'offers_nearby', with_empty_stock: '0')
      config = pharmapoint_config(cart: { rate_limit_per_minute: 1 })
      build_client(config:).offers_nearby(goods: lines, location: point)

      expect { build_client(config:).offers_nearby(goods: lines, location: point) }
        .to raise_error(Pharmapoint::RateLimited)
    end

    it 'treats a timeout as transient' do
      stub_request(
        :post,
        pharmapoint_url('order/get-drugstores-for-order-goods')
      ).with(query: hash_including({})).to_timeout

      expect { build_client.offers_nearby(goods: lines, location: point) }.to raise_error(Pharmapoint::TransientError)
    end
  end

  it 'holds calls back once the per-minute budget of the whole service is spent' do
    stub_pharmapoint('dictionaries', fixture: 'dictionaries')
    limited = build_client(config: pharmapoint_config(rate_limit: { per_minute: 1 }))
    limited.dictionaries

    expect { limited.dictionaries }.to raise_error(Pharmapoint::RateLimited)
  end
end
