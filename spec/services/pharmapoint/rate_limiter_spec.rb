# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::RateLimiter do
  let(:now) { Time.zone.parse('2026-10-07 12:00:30') }
  let(:clock) { class_double(Time, now:) }

  def limiter(**config) = described_class.new(config: pharmapoint_config(**config), clock:)

  it 'lets requests through while the minute budget lasts' do
    subject = limiter(rate_limit: { per_minute: 2 })

    expect { 2.times { subject.guard! } }.not_to raise_error
  end

  it 'asks to wait for the next minute once the budget is spent', :aggregate_failures do
    subject = limiter(rate_limit: { per_minute: 1 })
    subject.guard!

    expect { subject.guard! }.to raise_error(Pharmapoint::RateLimited) { expect(it.retry_after).to eq(30) }
  end

  it 'holds requests back for the window when the partner reports nothing left', :aggregate_failures do
    subject = limiter(rate_limit: { window: 45 })
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

  describe '#wait_time' do
    it 'is zero while the minute budget lasts, and spends nothing', :aggregate_failures do
      subject = limiter(rate_limit: { per_minute: 1 })

      expect(subject.wait_time).to eq(0)
      expect { subject.guard! }.not_to raise_error
    end

    it 'counts the seconds to the next minute once the budget is spent' do
      subject = limiter(rate_limit: { per_minute: 1 })
      subject.guard!

      expect(subject.wait_time).to eq(30)
    end

    it 'counts the seconds the partner asked to wait' do
      subject = limiter
      subject.block!(20)

      expect(subject.wait_time).to eq(20)
    end
  end

  describe 'the share of the search' do
    it 'refuses a search once its share is spent, without spending the budget of the others', :aggregate_failures do
      subject = limiter(rate_limit: { per_minute: 2 }, search: { rate_limit_per_minute: 1 })
      subject.guard!(share: :search)

      expect { subject.guard!(share: :search) }.to raise_error(Pharmapoint::RateLimited) { expect(it.retry_after).to eq(30) }
      expect { subject.guard! }.not_to raise_error
    end

    it 'refuses a search when the budget of the whole service is spent, though its share lasts' do
      subject = limiter(rate_limit: { per_minute: 1 }, search: { rate_limit_per_minute: 5 })
      subject.guard!

      expect { subject.guard!(share: :search) }.to raise_error(Pharmapoint::RateLimited)
    end

    it 'refuses a search while the partner asks to wait' do
      subject = limiter
      subject.block!(20)

      expect { subject.guard!(share: :search) }.to raise_error(Pharmapoint::RateLimited)
    end

    it 'gives its place in the share back when the budget of all refuses', :aggregate_failures do
      subject = limiter(rate_limit: { per_minute: 1 }, search: { rate_limit_per_minute: 2 })
      subject.guard!

      expect { subject.guard!(share: :search) }.to raise_error(Pharmapoint::RateLimited) { expect(it.retry_after).to eq(30) }
      expect(subject.share_left).to eq(2)
    end

    it 'keeps what was left of the share after the request it counted', :aggregate_failures do
      subject = limiter(search: { rate_limit_per_minute: 3 })

      expect { subject.guard!(share: :search) }.to change(subject, :share_left).from(nil).to(2)
      expect { subject.guard! }.not_to change(subject, :share_left)
    end
  end

  describe 'the share of the cart' do
    it 'refuses the cart once its share is spent, leaving the search its own share', :aggregate_failures do
      subject = limiter(cart: { rate_limit_per_minute: 1 }, search: { rate_limit_per_minute: 1 })
      subject.guard!(share: :cart)

      expect { subject.guard!(share: :cart) }.to raise_error(Pharmapoint::RateLimited)
      expect { subject.guard!(share: :search) }.not_to raise_error
    end

    it 'counts what is left of the share in the current minute' do
      subject = limiter(cart: { rate_limit_per_minute: 3 })

      expect { subject.guard!(share: :cart) }.to change(subject, :share_left).from(nil).to(2)
    end
  end

  it 'refuses a share it does not know' do
    expect { limiter.guard!(share: :booking) }.to raise_error(ArgumentError)
  end
end
