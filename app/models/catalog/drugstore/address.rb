# frozen_string_literal: true

class Catalog::Drugstore::Address < ApplicationRecord
  belongs_to :drugstore, class_name: 'Catalog::Drugstore', inverse_of: :address
  belongs_to :core_region, class_name: 'H24Core::Classification::Address::Region', optional: true, inverse_of: false
  belongs_to :core_settlement, class_name: 'H24Core::Classification::Address::Settlement', optional: true,
                               inverse_of: false
  belongs_to :core_city_district, class_name: 'H24Core::Classification::Address::CityDistrict', optional: true,
                                  inverse_of: false
  # core_metro_station_id has no association: the core has no metro stations table yet.

  validates :drugstore_id, uniqueness: true
  validates :address, presence: true
  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }
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
#  core_city_district_id :bigint
#  core_metro_station_id :bigint
#  core_region_id        :bigint
#  core_settlement_id    :bigint
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
