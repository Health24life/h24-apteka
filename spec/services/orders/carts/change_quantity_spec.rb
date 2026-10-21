# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Carts::ChangeQuantity do
  let(:cart) { create(:order, provider: create(:provider, code: 'pharmapoint')) }
  let(:owner) { Orders::Carts::Owner.new(user_id: nil, token: cart.token) }
  let(:item) { cart.items.first }

  before { stub_offers_adapter { |store, items| offer_for(store, items, available: 3) } }

  it 'sets the quantity checked live', :aggregate_failures do
    view = described_class.call(owner, item_id: item.id, quantity: 3)

    expect(item.reload.quantity).to eq(3)
    expect(view.items.sole.total).to eq(BigDecimal('300'))
  end

  it 'refuses more than the drugstore has, leaving the item as it was', :aggregate_failures do
    expect { described_class.call(owner, item_id: item.id, quantity: 4) }.to be_refused(code: :quantity_exceeds_stock)
    expect(item.reload.quantity).to eq(1)
  end

  it 'refuses an item of another cart' do
    other = create(:order).items.first

    expect { described_class.call(owner, item_id: other.id, quantity: 2) }
      .to be_refused(code: :cart_item_not_found, status: :not_found)
  end
end
