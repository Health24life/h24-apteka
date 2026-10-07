# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::ClearCart do
  it 'removes the cart together with all its items', :aggregate_failures do
    cart = create(:order, items_count: 3)

    expect { described_class.call(cart) }.to change(Order::Item, :count).by(-3)
    expect(Order.exists?(cart.id)).to be(false)
  end

  it 'returns the removed cart' do
    expect(described_class.call(create(:order))).to be_destroyed
  end

  it 'leaves the carts of others alone' do
    other = create(:order)

    described_class.call(create(:order))

    expect(Order.exists?(other.id)).to be(true)
  end

  it 'refuses an order that is no longer a cart', :aggregate_failures do
    sent = create(:order)
    sent.update_column(:state, 'submitted') # rubocop:disable Rails/SkipsModelValidations

    expect { described_class.call(sent) }.to raise_error(ArgumentError, /cart/)
    expect(Order.exists?(sent.id)).to be(true)
  end
end
