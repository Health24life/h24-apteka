# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Bookings::RefreshStatus do
  let(:order) { create(:order, :submitted, provider: create(:provider, code: 'pharmapoint'), status_name: 'created') }

  it "keeps the partner's status as the partner wrote it, with the time it was asked", :aggregate_failures do
    stub_bookings_adapter(submit: partner_order(status_name: 'processed_by_pharmacy'))

    described_class.call(order)

    expect(order.reload).to have_attributes(status_name: 'processed_by_pharmacy', status_synced_at: be_present)
  end

  it 'leaves the kept status when the partner does not answer, giving the failure back', :aggregate_failures do
    stub_bookings_adapter(submit: Orders::Bookings::Failure.new(reason: :unavailable, retry_after: nil))

    expect(described_class.call(order)).to have_attributes(reason: :unavailable)
    expect(order.reload.status_name).to eq('created')
  end

  describe '.stale?' do
    it 'is a sent order never asked, or asked longer ago than the minutes set', :aggregate_failures do
      expect(described_class.stale?(order)).to be(true)
      expect(described_class.stale?(order.tap { it.status_synced_at = 1.minute.ago })).to be(false)
      expect(described_class.stale?(order.tap { it.status_synced_at = 10.minutes.ago })).to be(true)
    end
  end
end
