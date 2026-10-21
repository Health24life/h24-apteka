# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Bookings::StatusPollWorker do
  it 'queues a refresh for every order whose status is still asked about' do
    order = create(:order, :submitted, personal_data_consent_at: 1.hour.ago)
    allow(Orders::Bookings::StatusRefreshWorker).to receive(:perform_async)

    described_class.new.perform

    expect(Orders::Bookings::StatusRefreshWorker).to have_received(:perform_async).with(order.id)
  end
end
