# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Bookings::Open do
  let(:order) { create(:order, :submitted, provider: create(:provider, code: 'pharmapoint'), status_name: 'created') }

  def owner = Orders::Carts::Owner.new(user_id: nil, token: order.token)

  it 'asks the provider for a stale status once in the minutes set, though it does not answer', :aggregate_failures do
    stub_bookings_adapter(submit: Orders::Bookings::Failure.new(reason: :unavailable, retry_after: nil))
    allow(Orders::Bookings::RefreshStatus).to receive(:call).and_call_original

    2.times { described_class.owned(owner) }

    expect(Orders::Bookings::RefreshStatus).to have_received(:call).once
    expect(order.reload.status_name).to eq('created')
  end

  it 'is nil for the token of a cart' do
    cart = create(:order)

    expect(described_class.owned(Orders::Carts::Owner.new(user_id: nil, token: cart.token))).to be_nil
  end
end
