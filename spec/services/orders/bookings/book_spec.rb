# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Bookings::Book do
  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:cart) { create(:order, provider:) }
  let(:owner) { Orders::Carts::Owner.new(user_id: nil, token: cart.token) }

  before do
    use_booking_config(drugstore_ids: [ cart.drugstore_id ])
    stub_offers_adapter { |store, items| offer_for(store, items, price: '100', available: 5) }
  end

  def book(body = booking_body(cart), by: owner) = described_class.call(by, Orders::Bookings::Request.from(body))

  it 'sends the cart with our own number, keeping its token', :aggregate_failures do
    adapter = stub_bookings_adapter

    order = book.order.reload

    expect(order).to have_attributes(state: 'submitted', token: cart.token, provider_order_number: 'PB-35-PT-H5')
    expect(adapter.submitted).to eq([ order.own_number ])
  end

  it 'takes the client, the consent and the wish to register' do
    stub_bookings_adapter

    expect(book.order.reload).to have_attributes(
      customer_first_name: 'Олена',
      customer_phone_number: '380671234567',
      register_account: true,
      personal_data_consent_at: be_present
    )
  end

  it 'keeps a snapshot with the confirmed prices and a pick-up paid in the drugstore', :aggregate_failures do
    stub_bookings_adapter

    order = book.order.reload

    expect([ order.delivery.delivery_type_code, order.payment.payment_type_code ]).to eq(%w[pick_up cash_in_store])
    expect(order.items.sole).to have_attributes(price: Money.from_amount(100, 'UAH'), name: cart.items.sole.goods.name)
  end

  it 'books at a lower live price without a new consent' do
    stub_bookings_adapter

    expect(book(booking_body(cart, price: '120')).order.reload.items.sole.price).to eq(Money.from_amount(100, 'UAH'))
  end

  it 'stops at a higher live price with the new prices, sending and saving nothing', :aggregate_failures do
    adapter = stub_bookings_adapter

    expect { book(booking_body(cart, price: '90')) }.to be_refused(
      code: :booking_prices_changed,
      status: :conflict,
      details: { items: [ include(goods_id: cart.items.sole.goods_id, price: '100.00', available: true) ] }
    )
    expect(adapter.submitted).to eq([])
    expect(cart.reload).to have_attributes(state: 'cart', own_number: nil)
  end

  it 'refuses a cart that changed, a drugstore out of the pilot and a missing consent', :aggregate_failures do
    expect { book(booking_body(cart).merge('goods' => [])) }.to be_refused(code: :cart_changed)
    expect { Orders::Bookings::Request.from(booking_body(cart, consent: false)) }
      .to be_refused(code: :personal_data_consent_required)

    use_booking_config(drugstore_ids: [])
    expect { book }.to be_refused(code: :booking_not_allowed_in_drugstore)
  end

  it "refuses an account's cart without the session of its user" do
    cart.update!(user_id: 7)

    expect { book }.to be_refused(code: :cart_not_found, status: :not_found)
  end

  it 'refuses without sending when the prices cannot be confirmed', :aggregate_failures do
    adapter = stub_bookings_adapter
    stub_offers_adapter { Orders::Offers::Failure.new(reason: :rate_limited, retry_after: 7) }

    expect { book }.to be_refused(code: :booking_check_busy, retry_after: 7)
    expect(adapter.submitted).to eq([])
  end

  it 'refuses the cart of a disabled provider without asking or sending it', :aggregate_failures do
    adapter = stub_bookings_adapter
    stub_offers_adapter { raise 'a disabled provider is asked' }
    provider.update!(active: false)

    expect { book }.to be_refused(code: :booking_check_unavailable, status: :service_unavailable)
    expect([ adapter.submitted, cart.reload.state ]).to eq([ [], 'cart' ])
  end

  describe 'a provider that did not take the order' do
    before { stub_bookings_adapter(submit: Orders::Bookings::Failure.new(reason: :unavailable, retry_after: nil)) }

    it 'leaves the order failed with its own number', :aggregate_failures do
      result = book

      expect(result.submitted).to be(false)
      expect(result.order.reload).to have_attributes(state: 'submission_failed', own_number: be_present)
    end
  end

  describe 'a retry' do
    let(:failed) do
      stub_bookings_adapter(submit: Orders::Bookings::Failure.new(reason: :unavailable, retry_after: nil))
      book.order.reload
    end

    it 'takes the order the provider made from the first attempt, sending nothing again', :aggregate_failures do
      own_number = failed.own_number
      adapter = stub_bookings_adapter(found: partner_order(number: 'FOUND-1'))

      order = book.order.reload

      expect(order).to have_attributes(state: 'submitted', provider_order_number: 'FOUND-1', own_number:)
      expect(adapter.submitted).to eq([])
    end

    it 'sends again with the same own number when the provider has no such order' do
      own_number = failed.own_number
      adapter = stub_bookings_adapter

      book

      expect(adapter.submitted).to eq([ own_number ])
    end

    it 'looks for the order by the phone the first attempt went with, though another one is given now' do
      failed
      adapter = stub_bookings_adapter

      book(booking_body(cart, customer: { 'phone_number' => '+380 50 765 43 21' }))

      expect(adapter.looked_up).to eq([ '380671234567' ])
    end

    it 'looks for the order since the first consent' do
      consent_at = failed.personal_data_consent_at
      seen = []
      stub_bookings_adapter(found: ->(since) { (seen << since) && nil })

      book

      expect(seen).to eq([ consent_at ])
    end
  end

  it 'refuses a booking of a cart that is being booked, sending nothing', :aggregate_failures do
    adapter = stub_bookings_adapter

    Orders::Bookings::Lease.hold("booking:#{cart.token}", 60) do
      expect { book }.to be_refused(code: :booking_in_progress, status: :conflict)
    end
    expect(adapter.submitted).to eq([])
  end

  it 'refuses an order already with the provider' do
    stub_bookings_adapter
    book

    expect { book }.to be_refused(code: :order_already_submitted, status: :conflict)
  end
end
