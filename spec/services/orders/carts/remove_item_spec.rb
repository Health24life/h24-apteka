# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Carts::RemoveItem do
  it 'removes the item and keeps a cart that still has other items', :aggregate_failures do
    cart = create(:order, items_count: 2)
    item = cart.items.first

    described_class.call(item)

    expect(Order::Item.exists?(item.id)).to be(false)
    expect(Order.exists?(cart.id)).to be(true)
  end

  it 'removes the cart together with its last item', :aggregate_failures do
    cart = create(:order)

    described_class.call(cart.items.first)

    expect(Order::Item.where(order_id: cart.id)).to be_empty
    expect(Order.exists?(cart.id)).to be(false)
  end

  it 'removes the cart when its items are removed one by one' do
    cart = create(:order, items_count: 3)

    cart.items.to_a.each { |item| described_class.call(item) }

    expect(Order.exists?(cart.id)).to be(false)
  end

  it 'returns the cart, which tells whether it went with its last item', :aggregate_failures do
    cart = create(:order, items_count: 2)
    first, last = cart.items.to_a

    expect(described_class.call(first)).not_to be_destroyed
    expect(described_class.call(last)).to be_destroyed
  end

  it 'keeps an order that is no longer a cart when its last item is removed' do
    sent = create(:order)
    sent.update_column(:state, 'submitted') # rubocop:disable Rails/SkipsModelValidations

    expect { described_class.call(sent.items.first) }.not_to change { Order.exists?(sent.id) }.from(true)
  end
end
