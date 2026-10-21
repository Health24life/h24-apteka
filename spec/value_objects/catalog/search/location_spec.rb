# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Search::Location do
  let(:config) { search_config(location: { latitude: 49.8397, longitude: 24.0297, radius: 25_000 }) }

  it 'rounds the coordinates of the user to about a kilometre' do
    location = described_class.around(latitude: 50.45012, longitude: 30.52741, radius: 5000, config:)

    expect(location).to have_attributes(latitude: 50.45, longitude: 30.53, radius: 5000)
  end

  it 'takes the configured point and radius for what the front left out', :aggregate_failures do
    expect(described_class.around(config:)).to have_attributes(latitude: 49.84, longitude: 24.03, radius: 25_000)
    expect(described_class.around(latitude: 50.45, longitude: 30.52, config:).radius).to eq(25_000)
  end
end
