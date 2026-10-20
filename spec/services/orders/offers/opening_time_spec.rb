# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Offers::OpeningTime do
  # Wednesday.
  let(:now) { Time.zone.local(2026, 10, 21, 22, 30) }
  let(:week) { [ '08:00-21:00', '08:00-21:00', '08:00-21:00', nil, '09:00-18:00', nil, nil ] }

  def offer(open_now:, opens_at: '08:00', closes_at: '21:00')
    Orders::Offers::DrugstoreOffer.unknown(1).with(open_now:, opens_at:, closes_at:)
  end

  def at(hour, minute = 0) = Time.zone.local(2026, 10, 21, hour, minute)

  it 'is nothing for a drugstore open now' do
    expect(described_class.call(offer(open_now: true), week, now:)).to be_nil
  end

  it 'is nothing when the provider told nothing of the hours' do
    expect(described_class.call(offer(open_now: nil), week, now:)).to be_nil
  end

  it "is today's opening when the drugstore has not opened yet" do
    expect(described_class.call(offer(open_now: false), week, now: at(7, 15))).to eq(at(8))
  end

  it "reads today's opening without a leading zero" do
    expect(described_class.call(offer(open_now: false, opens_at: '8:00'), week, now:))
      .to eq(Time.zone.local(2026, 10, 23, 9))
  end

  it "is today's opening from the week schedule when the provider told no hours" do
    expect(described_class.call(offer(open_now: false, opens_at: nil, closes_at: nil), week, now: at(7)))
      .to eq(at(8))
  end

  it 'is the opening of the next day with hours, on that day, reading the week from Monday' do
    expect(described_class.call(offer(open_now: false), week, now:)).to eq(Time.zone.local(2026, 10, 23, 9))
  end

  it 'is nothing for a drugstore closed within its hours, as for a break' do
    expect(described_class.call(offer(open_now: false), week, now: at(13, 30))).to be_nil
  end

  it 'reads hours that run past midnight as closing on the next day', :aggregate_failures do
    night = [ '20:00-02:00' ] * 7
    closed = offer(open_now: false, opens_at: nil, closes_at: nil)

    expect(described_class.call(closed, night, now: at(19))).to eq(at(20))
    expect(described_class.call(closed, night, now: at(23))).to be_nil
  end

  it 'is nothing without a week schedule' do
    expect(described_class.call(offer(open_now: false), [], now:)).to be_nil
  end
end
