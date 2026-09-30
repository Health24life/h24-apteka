# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_drugstore_address, class: 'Catalog::DrugstoreAddress' do
    drugstore factory: %i[catalog_drugstore]
    address { 'вул. Хрещатик, 1' }
    city { 'Київ' }
    state { 'Київська область' }
    latitude { 50.4501 }
    longitude { 30.5234 }
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
