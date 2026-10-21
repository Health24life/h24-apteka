# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Bookings::History do
  let(:config) { Orders::Bookings::Config.new.configure { it.update(history_per_page: 2, history_max_per_page: 3) } }

  def booked(hours_ago, user_id: 7)
    create(:order, :submitted, user_id:, personal_data_consent_at: hours_ago.hours.ago)
  end

  it "gives the account's bookings newest first" do
    older = booked(5)
    newer = booked(1)

    expect(described_class.call(user_id: 7, config:).orders).to eq([ newer, older ])
  end

  it "leaves out the account's cart, bookings of others and of guests" do
    create(:order, user_id: 7)
    booked(2, user_id: 8)
    create(:order, :submitted)

    expect(described_class.call(user_id: 7, config:).orders).to be_empty
  end

  it 'gives a page at a time and tells whether there is a next one', :aggregate_failures do
    3.times { booked(it + 1) }

    first = described_class.call(user_id: 7, config:)
    second = described_class.call(user_id: 7, page: 2, config:)

    expect([ first.orders.size, first.has_more ]).to eq([ 2, true ])
    expect([ second.orders.size, second.has_more ]).to eq([ 1, false ])
  end

  it 'refuses a page below one or a page size above the most allowed', :aggregate_failures do
    expect { described_class.call(user_id: 7, page: 0, config:) }.to be_refused(code: :invalid_page)
    expect { described_class.call(user_id: 7, per_page: 4, config:) }.to be_refused(code: :invalid_page)
  end
end
