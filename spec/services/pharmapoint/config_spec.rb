# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Config do
  subject(:config) { described_class.new }

  it 'has the defaults of the partner API', :aggregate_failures do
    expect(config.connection).to have_attributes(
      base_url: described_class::DEFAULT_BASE_URL,
      api_key: nil,
      open_timeout: 5,
      read_timeout: 30
    )
    expect(config.rate_limit).to have_attributes(per_minute: 60, window: 60)
    expect(config.goods_groups_per_page).to eq(50)
  end

  it 'reads numbers given as strings, as the environment gives them', :aggregate_failures do
    config.configure { it.update(rate_limit: { per_minute: '30' }, goods_groups_per_page: '20') }

    expect(config.rate_limit.per_minute).to eq(30)
    expect(config.goods_groups_per_page).to eq(20)
  end

  it 'refuses a number that is not one' do
    expect { config.configure { it.rate_limit.per_minute = 'many' } }.to raise_error(ArgumentError)
  end

  it 'treats an empty key as no key' do
    config.configure { it.connection.api_key = '' }

    expect(config.connection.api_key).to be_nil
  end

  it 'cannot be changed once finalized' do
    config.finalize!

    expect { config.configure { it.goods_groups_per_page = 1 } }.to raise_error(Dry::Configurable::FrozenConfigError)
  end

  describe '#credentials!' do
    def credentials(**connection) = described_class.new.configure { it.connection.update(connection) }.credentials!

    it 'returns the key and the domain name' do
      expect(credentials(api_key: 'k', domain_name: 'd')).to eq(%w[k d])
    end

    it 'refuses to go on without a key or a domain name', :aggregate_failures do
      expect { credentials(domain_name: 'd') }.to raise_error(Pharmapoint::ConfigurationError, /API_KEY/)
      expect { credentials(api_key: 'k') }.to raise_error(Pharmapoint::ConfigurationError, /DOMAIN_NAME/)
    end
  end

  describe '#retention_for' do
    it 'gives the period of a category, and of the other one for a category it does not know', :aggregate_failures do
      config.configure { it.log_retention_days.update(search: 3, other: 9) }

      expect(config.retention_for('search')).to eq(3.days)
      expect(config.retention_for('refund')).to eq(9.days)
    end
  end
end
