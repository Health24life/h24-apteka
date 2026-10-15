# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Pulls::Cooldown do
  let(:config) { pharmapoint_config(pull_cooldown: 15.minutes) }

  def paused(ids = %w[1 2], provider_id: 1) = described_class.paused(provider_id, :goods_group, ids)

  it 'pauses only the record it was asked to' do
    described_class.pause!(1, :goods_group, '1', config:)

    expect(paused).to eq(Set['1'])
  end

  it 'holds the pause for the configured time' do
    described_class.pause!(1, :goods_group, '1', config:)

    ttl = Sidekiq.redis { it.call('TTL', described_class.key(1, :goods_group, '1')) }
    expect(ttl).to be_between(899, 900)
  end

  it 'does not pause the same id of another provider' do
    described_class.pause!(1, :goods_group, '1', config:)

    expect(paused(provider_id: 2)).to be_empty
  end

  it 'asks Redis nothing for no ids', :aggregate_failures do
    allow(Sidekiq).to receive(:redis)

    expect(paused([])).to be_empty
    expect(Sidekiq).not_to have_received(:redis)
  end
end
