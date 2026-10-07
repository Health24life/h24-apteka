# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Config do
  describe '.from_env' do
    let(:env) do
      { 'PHARMAPOINT_BASE_URL' => 'https://p.test/api', 'PHARMAPOINT_API_KEY' => 'k',
        'PHARMAPOINT_DOMAIN_NAME' => 'h24.test', 'PHARMAPOINT_RATE_LIMIT_PER_MINUTE' => '30',
        'PHARMAPOINT_DRUGSTORE_SEARCH_POINTS' => '[{"latitude": 50.4, "longitude": 30.5, "radius": 20000}]' }
    end

    it 'reads the connection settings and the search points from the environment', :aggregate_failures do
      config = described_class.from_env(env)

      expect(config).to have_attributes(base_url: 'https://p.test/api', api_key: 'k', rate_limit_per_minute: 30)
      expect(config.search_points).to eq([ described_class::Point.new(latitude: 50.4, longitude: 30.5,
                                                                      radius: 20_000) ])
    end

    it 'treats an empty key as no key' do
      expect(described_class.from_env('PHARMAPOINT_API_KEY' => '').api_key).to be_nil
    end

    it 'uses the default retention of each log category, overridden one by one' do
      config = described_class.from_env('PHARMAPOINT_LOG_RETENTION_SEARCH_DAYS' => '3')

      expect(config.retention_days).to eq('booking' => 14, 'search' => 3, 'refresh' => 7, 'other' => 7)
    end
  end

  describe '#credentials!' do
    it 'returns the key and the domain name' do
      expect(described_class.new(api_key: 'k', domain_name: 'd').credentials!).to eq(%w[k d])
    end

    it 'refuses to go on without a key', :aggregate_failures do
      expect { described_class.new(domain_name: 'd').credentials! }
        .to raise_error(Pharmapoint::ConfigurationError, /API_KEY/)
      expect { described_class.new(api_key: 'k').credentials! }
        .to raise_error(Pharmapoint::ConfigurationError, /DOMAIN_NAME/)
    end
  end

  describe '#retention_for' do
    it 'falls back to the period of the other category for a category it does not know', :aggregate_failures do
      config = described_class.new(retention_days: { 'search' => 1, 'other' => 9 })

      expect(config.retention_for('search')).to eq(1.day)
      expect(config.retention_for('refund')).to eq(9.days)
    end
  end
end
