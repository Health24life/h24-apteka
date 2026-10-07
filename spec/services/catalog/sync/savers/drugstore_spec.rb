# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Savers::Drugstore do
  subject(:saver) { described_class.new(Catalog::Sync::Linker.new(provider)) }

  let(:provider) { create(:provider) }
  let(:listed) { Pharmapoint::Readers::Drugstores.list(JSON.parse(pharmapoint_fixture('drugstores'))).first }
  let(:full) { Pharmapoint::Readers::Drugstores.one(JSON.parse(pharmapoint_fixture('drugstore'))) }

  it 'keeps the code of the legal entity as a string with the leading zero' do
    record = listed.with(legal_entity_code: '01234567')

    expect(saver.call(record).drugstore_legal_entity_code).to eq('01234567')
  end

  it 'saves the address with single spaces and the coordinates', :aggregate_failures do
    drugstore = saver.call(listed)

    expect(drugstore.address).to have_attributes(address: 'м. Харків, вул. Чернишевська, 1', latitude: 49.995691,
                                                 city: 'Харків', state: 'Харківська обл.')
  end

  it 'keeps the phones as they came, in whatever format', :aggregate_failures do
    drugstore = saver.call(listed)

    expect(drugstore).to have_attributes(phone: '(093) 087-41-68', mobile_phone: nil)
  end

  it 'marks a new drugstore from the list as incomplete and one from its own record as complete', :aggregate_failures do
    expect(saver.call(listed)).to have_attributes(incomplete: true, name: nil)
    expect(saver.call(full)).to have_attributes(incomplete: false, name: 'Аптека №2369, "Подорожник"')
  end

  it 'does not blank the name when a list entry arrives after the full record', :aggregate_failures do
    saver.call(full)

    expect(saver.call(listed)).to have_attributes(incomplete: false, name: 'Аптека №2369, "Подорожник"',
                                                  ext_drugstore_id: '2369')
  end

  it 'takes a drugstore that came back off the withdrawn list' do
    drugstore = saver.call(full)
    drugstore.update!(withdrawn: true)

    expect(saver.call(full).withdrawn).to be(false)
  end

  it 'keeps the brand picture that only the full record knows when the list names the brand without it' do
    saver.call(full)
    record = listed.with(brand: listed.brand.with(image_path: nil))

    expect(saver.call(record).brand.image_path).to eq('drugstore_brand_photo/57/p.png')
  end

  it 'refuses a drugstore without coordinates and leaves the earlier one untouched', :aggregate_failures do
    saver.call(full)
    record = full.with(location: full.location.with(latitude: nil), contacts: full.contacts.with(phone: '000'))

    expect { saver.call(record) }.to raise_error(Catalog::Sync::MissingData)
    expect(Catalog::Drugstore.sole.phone).to eq('(093) 087-41-68')
  end

  it 'refuses a new drugstore without coordinates and creates nothing', :aggregate_failures do
    record = listed.with(location: listed.location.with(longitude: nil))

    expect { saver.call(record) }.to raise_error(Catalog::Sync::MissingData)
    expect(Catalog::Drugstore.count).to eq(0)
  end

  it 'refuses a code of the legal entity of the wrong length' do
    expect { saver.call(listed.with(legal_entity_code: '123')) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
