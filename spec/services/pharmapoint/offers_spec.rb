# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Offers do
  subject(:offers) { described_class.new(provider:, config: pharmapoint_config) }

  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:goods) { create(:catalog_goods) }
  let(:drugstore) { create(:catalog_drugstore) }

  before do
    create(:provider_link, provider:, linkable: goods, external_id: '1750321')
    create(:provider_link, provider:, linkable: drugstore, external_id: '510')
  end

  def stub_offers(path, fixture: nil, **answer)
    stub_request(
      :post,
      pharmapoint_url(path)
    ).with(query: hash_including({})).to_return(pharmapoint_answer(fixture, **answer))
  end

  describe '#nearby' do
    let(:location) { Catalog::Search::Location.new(latitude: 50.45, longitude: 30.52, radius: 25_000) }

    it 'gives the drugstores in the terms of the catalog, nil for one the directory does not have',
       :aggregate_failures do
      stub_offers('order/get-drugstores-for-order-goods', fixture: 'offers_nearby_priced')

      first, second = offers.nearby(goods, location)

      expect(first).to have_attributes(drugstore_id: drugstore.id, distance: 2216, open_now: true, opens_at: '10:00')
      expect(first.line_for(goods.id)).to have_attributes(
        fulfilled: true,
        price: BigDecimal('162.5'),
        available_quantity: 3
      )
      expect(second.drugstore_id).to be_nil
    end

    it 'asks for one pack of the SKU by its id at the partner' do
      stub = stub_offers('order/get-drugstores-for-order-goods', fixture: 'offers_nearby')

      offers.nearby(goods, location)

      expect(
        stub.with(
          body: hash_including(
            'goods' => [
              {
                'goods_id' => '1750321',
                'quantity' => 1
              }
            ]
          )
        )
      ).to have_been_requested
    end

    it 'keeps no data apart from no goods' do
      stub_offers('order/get-drugstores-for-order-goods', fixture: 'offers_nearby')

      expect(offers.nearby(goods, location).map(&:known?)).to eq([ false, false ])
    end
  end

  describe '#in_drugstore' do
    let(:item) { Order::Item.new(goods:, quantity: 2) }

    def answer(goods_id:, quantity: 1, fulfilled: true, drugstore_id: 510)
      {
        data: [
          {
            id: drugstore_id,
            order: {
              goods: [
                {
                  goods_id:,
                  is_fulfilled: fulfilled,
                  drugstore_price: 162.5,
                  quantity:
                }
              ]
            }
          }
        ]
      }.to_json
    end

    it 'gives what the drugstore has of the items', :aggregate_failures do
      stub = stub_offers('order/get-drugstore-for-order-goods', body: answer(goods_id: 1_750_321, quantity: 2))

      offer = offers.in_drugstore(drugstore, [ item ])

      expect(offer.line_for(goods.id)).to have_attributes(fulfilled: true, available_quantity: 2)
      expect(
        stub.with(
          body: {
            goods: [ { goods_id: '1750321', quantity: 2 } ],
            drugstore_id: '510'
          }
        )
      ).to have_been_requested
    end

    it 'reads a line of an id it did not ask about as not covered' do
      stub_offers('order/get-drugstore-for-order-goods', body: answer(goods_id: 999))

      expect(offers.in_drugstore(drugstore, [ item ]).line_for(goods.id)).to be_nil
    end

    it 'has no data when the answer does not have the drugstore', :aggregate_failures do
      stub_offers('order/get-drugstore-for-order-goods', body: answer(goods_id: 1_750_321, drugstore_id: 777))

      offer = offers.in_drugstore(drugstore, [ item ])

      expect(offer).to have_attributes(drugstore_id: drugstore.id, known?: false)
    end
  end

  describe 'a failure' do
    let(:path) { 'order/get-drugstores-for-order-goods' }
    let(:location) { Catalog::Search::Location.new(latitude: 50.45, longitude: 30.52, radius: 25_000) }

    it 'is unavailable when the partner is late' do
      stub_request(:post, pharmapoint_url(path)).with(query: hash_including({})).to_timeout

      expect(offers.nearby(goods, location)).to have_attributes(reason: :unavailable, retry_after: nil)
    end

    it 'is a limit refusal with the wait the partner asked for' do
      stub_offers(path, body: '{}', status: 429, headers: { 'Retry-After' => '17' })

      expect(offers.nearby(goods, location)).to have_attributes(reason: :rate_limited, retry_after: 17)
    end

    it 'is unavailable and reported on a refusal', :aggregate_failures do
      stub_offers(path, body: '{}', status: 422)
      allow(Rails.error).to receive(:report)

      expect(offers.nearby(goods, location).reason).to eq(:unavailable)
      expect(Rails.error).to have_received(:report).with(Pharmapoint::PermanentError, hash_including(handled: true))
    end

    it 'is unavailable and reported for a SKU the provider does not have, with no call', :aggregate_failures do
      allow(Rails.error).to receive(:report)

      expect(offers.nearby(create(:catalog_goods), location).reason).to eq(:unavailable)
      expect(a_request(:post, pharmapoint_url(path)).with(query: hash_including({}))).not_to have_been_requested
    end

    it 'is unavailable without a key, with no call' do
      allow(Rails.error).to receive(:report)
      keyless = described_class.new(provider:, config: pharmapoint_config(connection: { api_key: '' }))

      expect(keyless.nearby(goods, location).reason).to eq(:unavailable)
    end
  end
end
