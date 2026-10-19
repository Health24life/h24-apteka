# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Offers::OpeningTime do
  # Wednesday.
  let(:now) { Time.zone.local(2026, 10, 21, 22, 30) }
  let(:week) { [ '08:00-21:00', '08:00-21:00', '08:00-21:00', nil, '09:00-18:00', nil, nil ] }

  def offer(open_now:, opens_at: '08:00') = Orders::Offers::DrugstoreOffer.unknown(1).with(open_now:, opens_at:)

  it 'is nothing for a drugstore open now' do
    expect(described_class.call(offer(open_now: true), week, now:)).to be_nil
  end

  it 'is nothing when the provider told nothing of the hours' do
    expect(described_class.call(offer(open_now: nil), week, now:)).to be_nil
  end

  it "is today's opening when the drugstore has not opened yet" do
    early = Time.zone.local(2026, 10, 21, 7, 15)

    expect(described_class.call(offer(open_now: false), week, now: early)).to eq('08:00')
  end

  it 'is the opening of the next day with hours, reading the week from Monday' do
    expect(described_class.call(offer(open_now: false), week, now:)).to eq('09:00')
  end

  it 'is nothing without a week schedule' do
    expect(described_class.call(offer(open_now: false), [], now:)).to be_nil
  end
end
