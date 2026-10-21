# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Carts::Show do
  let(:cart) { create(:order, provider: create(:provider, code: 'pharmapoint'), items_count: 2) }
  let(:owner) { Orders::Carts::Owner.new(user_id: nil, token: cart.token) }
  let(:first_item) { cart.items.order(:id).first }

  it 'gives the items with live prices and the total of what is available', :aggregate_failures do
    stub_offers_adapter { |drugstore, items| offer_for(drugstore, items, price: '50.5') }
    first_item.update!(quantity: 2)

    view = described_class.call(owner)

    expect(view.items.map { [ it.available?, it.price, it.total ] })
      .to eq([ [ true, BigDecimal('50.5'), BigDecimal('101') ], [ true, BigDecimal('50.5'), BigDecimal('50.5') ] ])
    expect(view).to have_attributes(prices_available: true, total: BigDecimal('151.5'))
  end

  it 'keeps an item the drugstore cannot cover in full, without its price' do
    stub_offers_adapter { |drugstore, items| offer_for(drugstore, items, available: 1) }
    first_item.update!(quantity: 2)

    lines = described_class.call(owner).items.map { [ it.available?, it.price ] }

    expect(lines).to eq([ [ false, nil ], [ true, BigDecimal('100') ] ])
  end

  it 'shows the cart without prices when the provider does not answer', :aggregate_failures do
    stub_offers_adapter { Orders::Offers::Failure.new(reason: :unavailable, retry_after: nil) }

    view = described_class.call(owner)

    expect(view).to have_attributes(prices_available: false, total: BigDecimal(0))
    expect(view.items.map(&:available?)).to eq([ false, false ])
  end

  it 'shows the cart of a disabled provider without prices, not asking it', :aggregate_failures do
    stub_offers_adapter { raise 'a disabled provider is asked' }
    cart.provider.update!(active: false)

    view = described_class.call(owner)

    expect(view).to have_attributes(prices_available: false)
    expect(view.items.size).to eq(2)
  end

  it 'tells what it took out' do
    stub_offers_adapter { |drugstore, items| offer_for(drugstore, items) }
    first_item.goods.update!(hidden: true)

    expect(described_class.call(owner).removed.map(&:reason)).to eq([ :goods_hidden ])
  end

  it 'refuses a cart that is not there' do
    expect { described_class.call(Orders::Carts::Owner.new(user_id: nil, token: 'nope')) }
      .to be_refused(code: :cart_not_found, details: nil)
  end

  it 'refuses a cart that went whole, with the reason' do
    cart.drugstore.update!(hidden: true)

    expect { described_class.call(owner) }.to be_refused(code: :cart_not_found, details: { reason: :drugstore_hidden })
  end
end
