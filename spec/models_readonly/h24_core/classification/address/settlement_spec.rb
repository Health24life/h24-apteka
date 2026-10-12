# frozen_string_literal: true

require 'rails_helper'

RSpec.describe H24Core::Classification::Address::Settlement do
  describe '#center' do
    it 'returns latitude and longitude when both are known' do
      expect(build(:h24_core_settlement, latitude: 50.45, longitude: 30.52).center).to eq([ 50.45, 30.52 ])
    end

    it 'is nil when the core has no coordinates', :aggregate_failures do
      expect(build(:h24_core_settlement, latitude: nil, longitude: nil).center).to be_nil
      expect(build(:h24_core_settlement, latitude: 50.45, longitude: nil).center).to be_nil
    end
  end

  it 'knows its region and its city districts', :aggregate_failures do
    region = create(:h24_core_region)
    settlement = create(:h24_core_settlement, region_id: region.id)
    district = create(:h24_core_city_district, settlement_id: settlement.id)

    expect(settlement.region).to eq(region)
    expect(settlement.city_districts).to contain_exactly(district)
  end
end
