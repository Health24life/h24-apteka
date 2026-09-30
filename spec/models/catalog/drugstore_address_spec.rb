# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::DrugstoreAddress do
  subject(:address) { build(:catalog_drugstore_address) }

  it { is_expected.to be_valid }
  it { is_expected.to validate_presence_of(:address) }
  it { is_expected.to validate_presence_of(:latitude) }
  it { is_expected.to validate_presence_of(:longitude) }

  it 'keeps the city and region exactly as the provider gave them, and they may be missing' do
    address = create(:catalog_drugstore_address, city: 'м. Київ', state: nil)

    expect(address.reload).to have_attributes(city: 'м. Київ', state: nil)
  end

  it 'limits coordinates to the globe', :aggregate_failures do
    expect(build(:catalog_drugstore_address, latitude: 90, longitude: -180)).to be_valid
    expect(build(:catalog_drugstore_address, latitude: 90.1)).not_to be_valid
    expect(build(:catalog_drugstore_address, longitude: 180.1)).not_to be_valid
  end

  it 'refuses coordinates off the globe at the database level' do
    address = create(:catalog_drugstore_address)

    expect { address.update_column(:latitude, 91) }.to raise_error(ActiveRecord::StatementInvalid) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'allows one address per drugstore' do
    first = create(:catalog_drugstore_address)

    expect(build(:catalog_drugstore_address, drugstore: first.drugstore)).not_to be_valid
  end

  it 'refuses a second address of a drugstore at the database level' do
    first = create(:catalog_drugstore_address)
    second = build(:catalog_drugstore_address, drugstore: first.drugstore)

    expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'links to core region, settlement and city district', :aggregate_failures do
    region, settlement, district = %i[h24_core_region h24_core_settlement h24_core_city_district].map { create(it) }
    linked = create(:catalog_drugstore_address, core_region_id: region.id, core_settlement_id: settlement.id,
                                                core_city_district_id: district.id)

    expect(linked).to have_attributes(core_region: region, core_settlement: settlement, core_city_district: district)
  end

  it 'leaves the core links optional' do
    expect(create(:catalog_drugstore_address).core_region).to be_nil
  end

  it 'keeps the metro station id without an association', :aggregate_failures do
    address = create(:catalog_drugstore_address, core_metro_station_id: 7)

    expect(address.reload.core_metro_station_id).to eq(7)
    expect(described_class.reflect_on_association(:core_metro_station)).to be_nil
  end
end

# == Schema Information
#
# Table name: catalog_drugstore_addresses
#
#  id                    :bigint           not null, primary key
#  address               :string           not null
#  city                  :string
#  latitude              :decimal(10, 7)   not null
#  longitude             :decimal(10, 7)   not null
#  state                 :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  core_city_district_id :integer
#  core_metro_station_id :integer
#  core_region_id        :integer
#  core_settlement_id    :integer
#  drugstore_id          :bigint           not null
#
# Indexes
#
#  index_catalog_drugstore_addresses_on_drugstore_id  (drugstore_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (drugstore_id => catalog_drugstores.id) ON DELETE => cascade
#
# Check Constraints
#
#  catalog_drugstore_addresses_latitude_check   (latitude >= '-90'::integer::numeric AND latitude <= 90::numeric)
#  catalog_drugstore_addresses_longitude_check  (longitude >= '-180'::integer::numeric AND longitude <= 180::numeric)
#
