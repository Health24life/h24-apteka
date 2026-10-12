# frozen_string_literal: true

require 'rails_helper'

RSpec.describe H24Core::Classification::Address::Region do
  it 'reads the title with fallbacks and lists its settlements', :aggregate_failures do
    region = create(:h24_core_region, title_translations: { 'uk' => 'Львівська область', 'en' => 'Lviv Oblast' })
    settlement = create(:h24_core_settlement, region_id: region.id)

    expect(I18n.with_locale(:en) { region.title }).to eq('Lviv Oblast')
    expect(region.settlements).to contain_exactly(settlement)
  end
end
