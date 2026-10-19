# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Bookings::StatusRefreshWorker do
  let(:order) { create(:order, :submitted, provider: create(:provider, code: 'pharmapoint')) }

  it 'refreshes the status of a sent order' do
    stub_bookings_adapter(submit: partner_order(status_name: 'processed_by_pharmacy'))

    described_class.new.perform(order.id)

    expect(order.reload.status_name).to eq('processed_by_pharmacy')
  end

  it 'puts the job off for the wait the partner asked on a refusal for the limit' do
    stub_bookings_adapter(submit: Orders::Bookings::Failure.new(reason: :rate_limited, retry_after: 30))
    allow(described_class).to receive(:perform_in)

    described_class.new.perform(order.id)

    expect(described_class).to have_received(:perform_in).with(30, order.id)
  end

  it 'leaves an order that is not sent' do
    stub_bookings_adapter

    expect { described_class.new.perform(create(:order).id) }.not_to raise_error
  end
end
