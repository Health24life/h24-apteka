# frozen_string_literal: true

require 'rails_helper'

RSpec.describe H24Core::Classification::Address::CityDistrict do
  it 'belongs to a settlement and reads its title', :aggregate_failures do
    settlement = create(:h24_core_settlement)
    district = create(:h24_core_city_district, settlement_id: settlement.id,
                                               title_translations: { 'uk' => 'Подільський' })

    expect(district.settlement).to eq(settlement)
    expect(district.title).to eq('Подільський')
  end
end
