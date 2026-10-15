# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'the settings built from the environment at boot' do # rubocop:disable RSpec/DescribeClass
  it 'takes the values the environment sets', :aggregate_failures do
    expect(Pharmapoint.config.rate_limit.per_minute).to eq(Integer(ENV.fetch('PHARMAPOINT_RATE_LIMIT_PER_MINUTE', 60)))
    expect(Catalog::Sync.config.pull.stash_ttl).to eq(Integer(ENV.fetch('CATALOG_SYNC_STASH_TTL', 600)).seconds)
  end

  it 'keeps the default of a setting the environment leaves empty' do
    expect(Pharmapoint.config.connection.base_url).to eq(ENV['PHARMAPOINT_BASE_URL'].presence ||
                                                         Pharmapoint::Config::DEFAULT_BASE_URL)
  end

  it 'freezes both', :aggregate_failures do
    expect(Pharmapoint.config.config).to be_frozen
    expect(Catalog::Sync.config.config).to be_frozen
  end
end
