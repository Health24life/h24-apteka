# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Producer do
  it { is_expected.to validate_presence_of(:name) }

  it 'accepts a two-letter upper-case country code or none', :aggregate_failures do
    expect(build(:catalog_producer, country_code: 'UA')).to be_valid
    expect(build(:catalog_producer, country_code: nil)).to be_valid
    expect(build(:catalog_producer, country_code: '')).to be_valid
  end

  it 'refuses other country code shapes', :aggregate_failures do
    %w[ua UKR U 1A].each do |code|
      expect(build(:catalog_producer, country_code: code)).not_to be_valid
    end
  end

  it 'refuses a malformed country code at the database level' do
    producer = create(:catalog_producer)

    expect { producer.update_column(:country_code, 'ua') }.to raise_error(ActiveRecord::StatementInvalid) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'resolves the core country by code' do
    country = create(:h24_core_country, code: 'UA')

    expect(create(:catalog_producer, country_code: 'UA').core_country).to eq(country)
  end

  it 'has no core country when the code is unknown or absent', :aggregate_failures do
    expect(create(:catalog_producer, country_code: 'ZZ').core_country).to be_nil
    expect(create(:catalog_producer, country_code: nil).core_country).to be_nil
  end
end

# == Schema Information
#
# Table name: catalog_producers
#
#  id           :bigint           not null, primary key
#  country      :string
#  country_code :string(2)
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Check Constraints
#
#  catalog_producers_country_code_check  (country_code IS NULL OR country_code::text ~ '^[A-Z]{2}$'::text)
#
