# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::Drugstores do
  let(:list) { described_class.list(JSON.parse(pharmapoint_fixture('drugstores'))) }

  it 'reads the legal entity, the address with coordinates and the brand', :aggregate_failures do
    expect(list.first).to include(external_id: '38628', legal_entity_code: '42517597', latitude: 49.995691,
                                  longitude: 36.2359392, address: 'м. Харків, вул. Чернишевська, 1',
                                  work_with_reimbursement: true)
    expect(list.first[:brand]).to eq(external_id: '57', name: 'Подорожник',
                                     image_path: 'drugstore_brand_photo/57/p.png')
  end

  it 'keeps the seven entries of the week schedule' do
    expect(list.first[:week_working_hours].size).to eq(7)
  end

  it 'does not read the distance and the working hours of today', :aggregate_failures do
    expect(list.first.keys.map(&:to_s)).not_to include('distance', 'working_hours')
    expect(list.first.to_s).not_to include('1910')
  end

  it 'marks a record without the name, the outer code and the city id as incomplete' do
    expect(list.pluck(:complete)).to eq([ false, false ])
  end

  it 'keeps the phones as they came' do
    expect(list.first[:phone]).to eq('(093) 087-41-68')
  end

  it 'unpacks a single drugstore that arrives as an array of one and marks it complete' do
    one = described_class.one(JSON.parse(pharmapoint_fixture('drugstore')))

    expect(one).to include(external_id: '38628', outer_id: '2369', name: 'Аптека №2369, "Подорожник"', complete: true)
  end

  it 'refuses an answer without data' do
    expect { described_class.list({}) }.to raise_error(Pharmapoint::InvalidResponse)
  end
end
