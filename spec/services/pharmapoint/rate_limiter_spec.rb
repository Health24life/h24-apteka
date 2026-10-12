# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::RateLimiter do
  let(:now) { Time.zone.parse('2026-10-07 12:00:30') }
  let(:clock) { class_double(Time, now:) }

  def limiter(**config) = described_class.new(config: pharmapoint_config(**config), clock:)

  it 'lets requests through while the minute budget lasts' do
    subject = limiter(rate_limit_per_minute: 2)

    expect { 2.times { subject.guard! } }.not_to raise_error
  end

  it 'asks to wait for the next minute once the budget is spent', :aggregate_failures do
    subject = limiter(rate_limit_per_minute: 1)
    subject.guard!

    expect { subject.guard! }.to raise_error(Pharmapoint::RateLimited) { expect(it.retry_after).to eq(30) }
  end

  it 'holds requests back for the window when the partner reports nothing left', :aggregate_failures do
    subject = limiter(rate_limit_window: 45)
    subject.record('x-ratelimit-remaining' => '0')

    expect { subject.guard! }.to raise_error(Pharmapoint::RateLimited) { expect(it.retry_after).to eq(45) }
  end

  it 'does not hold requests back while the partner reports some limit left' do
    subject = limiter
    subject.record('x-ratelimit-remaining' => '17')

    expect { subject.guard! }.not_to raise_error
  end

  it 'is shared between instances, so every worker sees the same block' do
    limiter.block!(20)

    expect { limiter.guard! }.to raise_error(Pharmapoint::RateLimited)
  end
end
