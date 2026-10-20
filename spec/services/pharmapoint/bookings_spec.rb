# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Bookings do
  subject(:bookings) { described_class.new(provider:, config: pharmapoint_config) }

  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:order) { sent_order }

  def sent_order
    order = create(
      :order,
      :submission_failed,
      provider:,
      provider_drugstore_external_id: '34494',
      own_number: 'K7Q2M9XA1B'
    )
    order.items.first.update!(provider_goods_external_id: '1990718', quantity: 2, price: 12.5, total: 25)
    order.update!(customer_last_name: 'Коваль', customer_email: 'olena@example.com')
    order.reload
  end

  describe '#submit' do
    it 'sends a pick-up paid in the drugstore with our own number and the confirmed prices', :aggregate_failures do
      stub = stub_request(:post, pharmapoint_url('order/store-pick-up-order'))
        .to_return(pharmapoint_answer('partner_order_created', status: 201))

      expect(bookings.submit(order).number).to eq('2E-2H-X4-K5')
      expect(
        stub.with(
          body: hash_including(
            'drugstore_id' => '34494',
            'customer_first_name' => 'Anna',
            'customer_phone_number' => '380501234567',
            'delivery' => { 'delivery_type_code' => 'pick_up' },
            'payment' => { 'payment_method_code' => 'cash_in_store' },
            'goods' => [ { 'goods_id' => '1990718', 'quantity' => 2, 'price' => '12.50' } ],
            'online_drugstore_order_number' => 'K7Q2M9XA1B',
            'total' => '25.00'
          )
        )
      ).to have_been_requested
    end

    it 'logs the call as a booking, with the phone of the client masked', :aggregate_failures do
      stub_request(
        :post,
        pharmapoint_url('order/store-pick-up-order')
      ).to_return(pharmapoint_answer('partner_order_created'))

      bookings.submit(order)

      log = Provider::RequestLog.last
      expect(log.category).to eq('booking')
      expect(log.request_body['customer_phone_number']).to eq('[masked]')
    end

    it 'is unavailable when the partner is late, and refused and reported on a 4xx', :aggregate_failures do
      allow(Rails.error).to receive(:report)
      stub_request(:post, pharmapoint_url('order/store-pick-up-order')).to_timeout.then.to_return(
        status: 422,
        body: '{}'
      )

      expect(bookings.submit(order).reason).to eq(:unavailable)
      expect(bookings.submit(order).reason).to eq(:refused)
      expect(Rails.error).to have_received(:report).once
    end
  end

  describe '#status' do
    it "reads the order by the partner's number" do
      order.update!(state: 'submitted', provider_order_number: 'PB-35-PT-H5')
      stub_request(:get, pharmapoint_url('order/PB-35-PT-H5')).to_return(pharmapoint_answer('partner_order'))

      expect(bookings.status(order)).to have_attributes(number: 'PB-35-PT-H5', status_name: 'created')
    end
  end

  describe '#cancel' do
    before { order.update!(state: 'submitted', provider_order_number: 'PB-35-PT-H5') }

    it "asks the partner to cancel by its number, with the client's phone and the reason", :aggregate_failures do
      stub = stub_request(:post, pharmapoint_url('order/cancel')).to_return(status: 200, body: '')

      expect(bookings.cancel(order, reason: 'Передумала')).to be(true)
      expect(
        stub.with(
          body: { order_number: 'PB-35-PT-H5', cancel_reason: 'Передумала' },
          headers: { 'Customer-Phone' => '380501234567' }
        )
      ).to have_been_requested
    end

    it 'is refused when the partner refuses, and unavailable when it does not answer', :aggregate_failures do
      allow(Rails.error).to receive(:report)
      stub_request(:post, pharmapoint_url('order/cancel')).to_return(status: 422, body: '{}').then.to_timeout

      expect(bookings.cancel(order, reason: 'x').reason).to eq(:refused)
      expect(bookings.cancel(order, reason: 'x').reason).to eq(:unavailable)
    end
  end

  describe '#find_submitted' do
    def history(drugstore_id: 34_494, created_at: '2026-10-19 12:00:00', goods_id: 1_990_718, quantity: 2)
      body = { data: [ { order_number: 'PB-35', drugstore_id:, created_at:, goods: [ { goods_id:, quantity: } ] } ] }
      stub_request(:get, pharmapoint_url('order/history')).with(query: hash_including({}))
        .to_return(pharmapoint_answer(nil, body: body.to_json))
    end

    let(:since) { Time.find_zone('Europe/Kyiv').local(2026, 10, 19, 11, 59) }

    it 'finds the order of the client in the same drugstore, made since the first attempt, with the same goods',
       :aggregate_failures do
      stub = history

      expect(bookings.find_submitted(order, since:).number).to eq('PB-35')
      expect(stub.with(headers: { 'Customer-Phone' => '380501234567' })).to have_been_requested
    end

    it 'does not take an order of another drugstore, an earlier one or one with other quantities',
       :aggregate_failures do
      history(drugstore_id: 1)
      expect(bookings.find_submitted(order, since:)).to be_nil

      history(created_at: '2026-10-19 11:00:00')
      expect(bookings.find_submitted(order, since:)).to be_nil

      history(quantity: 1)
      expect(bookings.find_submitted(order, since:)).to be_nil
    end

    it 'is unavailable when the history does not answer' do
      stub_request(:get, pharmapoint_url('order/history')).with(query: hash_including({})).to_timeout

      expect(bookings.find_submitted(order, since:).reason).to eq(:unavailable)
    end
  end
end
