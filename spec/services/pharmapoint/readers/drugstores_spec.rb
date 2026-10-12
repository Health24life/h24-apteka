# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::Drugstores do
  let(:list) { described_class.list(JSON.parse(pharmapoint_fixture('drugstores'))) }

  it 'reads the legal entity and whether the drugstore works with reimbursement', :aggregate_failures do
    expect(list.first).to have_attributes(external_id: '38628', legal_entity_code: '42517597',
                                          work_with_reimbursement: true)
    expect(list.first.legal_entity_name).to include('Подорожник Харків')
  end

  it 'reads the address with the coordinates, spaces squeezed' do
    expect(list.first.location).to have_attributes(address: 'м. Харків, вул. Чернишевська, 1', city: 'Харків',
                                                   state: 'Харківська обл.', latitude: 49.995691,
                                                   longitude: 36.2359392)
  end

  it 'reads the brand' do
    expect(list.first.brand).to eq(Pharmapoint::Brand.new(external_id: '57', name: 'Подорожник',
                                                          image_path: 'drugstore_brand_photo/57/p.png'))
  end

  it 'keeps the seven entries of the week schedule' do
    expect(list.first.week_working_hours.size).to eq(7)
  end

  it 'keeps the phones as they came, without a phone where there is none', :aggregate_failures do
    expect(list.first.contacts).to have_attributes(phone: '(093) 087-41-68', mobile_phone: nil)
    expect(list.second.contacts).to have_attributes(phone: '380445949238', email: nil)
  end

  it 'has no place for the distance and the working hours of today', :aggregate_failures do
    members = [ Pharmapoint::Drugstore, Pharmapoint::Location, Pharmapoint::Contacts ].flat_map(&:members)

    expect(members & %i[distance working_hours is_open]).to be_empty
    expect(list.first.as_json.to_s).not_to include('1910')
  end

  it 'marks a record without the name, the outer code and the city id as incomplete' do
    expect(list.map(&:complete)).to eq([ false, false ])
  end

  it 'unpacks a single drugstore that arrives as an array of one and marks it complete' do
    one = described_class.one(JSON.parse(pharmapoint_fixture('drugstore')))

    expect(one).to have_attributes(external_id: '38628', outer_id: '2369', name: 'Аптека №2369, "Подорожник"',
                                   complete: true)
  end

  it 'refuses an answer without data' do
    expect { described_class.list({}) }.to raise_error(Pharmapoint::InvalidResponse)
  end
end
