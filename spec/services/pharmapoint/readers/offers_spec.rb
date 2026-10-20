# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::Offers do
  def read(fixture) = described_class.call(JSON.parse(pharmapoint_fixture(fixture)))

  it "reads every drugstore with its distance and today's hours", :aggregate_failures do
    offer = read('offers_nearby').first

    expect(offer).to have_attributes(drugstore_external_id: '510', distance: 2216)
    expect(offer.today_hours).to have_attributes(from: '10:00', to: '21:00', open: true, round_the_clock: false)
  end

  it 'tells no data from no goods: an order of null has no items' do
    expect(read('offers_nearby').first.items).to be_nil
  end

  it 'reads the in-drugstore price and the quantity of a line, never the online price', :aggregate_failures do
    item = read('offers_in_drugstore').first.items.first

    expect(item).to have_attributes(
      goods_external_id: '7592415d-7896-11e4-881f-001d60d868ae',
      fulfilled: true,
      price: BigDecimal('162.5'),
      quantity: BigDecimal('1')
    )
  end

  it 'keeps a line the drugstore does not cover, with nothing of it' do
    item = read('offers_nearby_priced').second.items.first

    expect(item).to have_attributes(fulfilled: false, price: BigDecimal('0'), quantity: BigDecimal('0'))
  end

  it 'reads a float price as the price the partner meant' do
    body = {
      'data' => [
        {
          'id' => 1,
          'order' => {
            'goods' => [
              {
                'goods_id' => 7,
                'drugstore_price' => 80.989999999999995
              }
            ]
          }
        }
      ]
    }

    expect(described_class.call(body).first.items.first.price).to eq(BigDecimal('80.99'))
  end

  it 'skips a drugstore or a line without an id' do
    body = { 'data' => [ { 'order' => nil }, { 'id' => 2, 'order' => { 'goods' => [ { 'quantity' => 1 } ] } } ] }

    expect(described_class.call(body).map { [ it.drugstore_external_id, it.items ] }).to eq([ [ '2', [] ] ])
  end

  it 'refuses an answer with no data' do
    expect { described_class.call({ 'meta' => {} }) }.to raise_error(Pharmapoint::InvalidResponse)
  end
end
