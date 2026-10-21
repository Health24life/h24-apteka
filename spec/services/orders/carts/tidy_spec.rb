# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Carts::Tidy do
  let(:cart) { create(:order, items_count: 2) }

  it 'leaves a cart that is still good as it is' do
    expect(described_class.call(cart)).to have_attributes(cart:, removed: [], reason: nil)
  end

  it 'keeps the cart of a disabled provider, which may come back' do
    cart.provider.update!(active: false)

    expect(described_class.call(cart)).to have_attributes(cart:, removed: [], reason: nil)
  end

  it 'ends the cart of a hidden or withdrawn drugstore', :aggregate_failures do
    cart.drugstore.update!(withdrawn: true)

    expect(described_class.call(cart)).to have_attributes(cart: nil, reason: :drugstore_hidden)
    expect(Order.exists?(cart.id)).to be(false)
  end

  it 'takes out the item of a SKU hidden alone or with its group, or withdrawn', :aggregate_failures do
    hidden, kept = cart.items.order(:id).to_a
    hidden.goods.goods_group.update!(hidden: true)

    tidied = described_class.call(cart)

    expect(tidied.removed.map { [ it.reason, it.goods ] }).to eq([ [ :goods_hidden, hidden.goods ] ])
    expect(cart.items.reload).to eq([ kept ])
  end

  it 'ends the cart with its last item', :aggregate_failures do
    cart.items.each { it.goods.update!(withdrawn: true) }

    tidied = described_class.call(cart)

    expect(tidied).to have_attributes(cart: nil, reason: :items_removed)
    expect(tidied.removed.map(&:reason)).to eq(%i[goods_withdrawn goods_withdrawn])
  end
end
