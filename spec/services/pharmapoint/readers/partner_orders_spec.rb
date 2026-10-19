# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::PartnerOrders do
  def fixture(name) = JSON.parse(pharmapoint_fixture(name))

  it 'reads a made order: its numbers, status, drugstore and lines', :aggregate_failures do
    order = described_class.one(fixture('partner_order_created'))

    expect(order).to have_attributes(
      number: '2E-2H-X4-K5',
      customer_number: '123456',
      status_name: 'created',
      drugstore_external_id: '34494'
    )
    expect(order.lines.map { [ it.goods_external_id, it.quantity ] }).to eq([ [ '1990718', BigDecimal(1) ] ])
  end

  it 'reads the time of the partner, which has no zone, as Kyiv time' do
    expect(described_class.one(fixture('partner_order_created')).created_at)
      .to eq(Time.find_zone('Europe/Kyiv').local(2023, 1, 26, 14, 53, 8))
  end

  it 'keeps the whole object the partner gave' do
    expect(described_class.one(fixture('partner_order_created')).record)
      .to include('order_number_for_customer' => '123456')
  end

  it 'reads the orders of a history' do
    expect(described_class.many(fixture('partner_order_history')).map(&:number)).to eq(
      %w[
        4T-3X-BK-96
        5E-64-49-96
        9K-28-37-72
      ]
    )
  end

  it 'refuses an answer with no order' do
    expect { described_class.one({ 'data' => {} }) }.to raise_error(Pharmapoint::InvalidResponse)
  end
end
