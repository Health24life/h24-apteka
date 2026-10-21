# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Carts::RemoveAbandoned do
  include ActiveSupport::Testing::TimeHelpers

  let(:config) { Orders::Carts::Config.new.configure { it.guest_ttl_days = 7 } }

  def made(days_ago, *traits, **) = travel_to(days_ago.days.ago) { create(:order, *traits, **) }

  it "removes the guest carts unchanged for longer than the days set, keeping an account's cart and a sent order" do
    kept = [ made(6), made(30, user_id: 3), made(30, :submitted) ]
    made(8)

    described_class.call(config:)

    expect(Order.all).to match_array(kept)
  end

  it 'tells how many carts went' do
    made(8)

    expect(described_class.call(config:)).to eq(1)
  end
end
