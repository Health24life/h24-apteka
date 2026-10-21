# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Bookings::DueForStatus do
  def booked(days_ago, *traits, **) = create(:order, *traits, personal_data_consent_at: days_ago.days.ago, **)

  it 'gives the sent orders of the last days whose status is not final or not known yet' do
    due = [ booked(1, :submitted, status_name: 'created'), booked(2, :submitted, status_name: nil) ]

    expect(described_class.call).to match_array(due)
  end

  it 'leaves out a final status, an order booked too long ago, a failed sending and a cart' do
    booked(1, :submitted, status_name: 'canceled')
    booked(5, :submitted, status_name: 'created')
    booked(1, :submission_failed)
    create(:order)

    expect(described_class.call).to be_empty
  end
end
