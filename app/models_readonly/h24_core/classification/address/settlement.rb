# frozen_string_literal: true

class H24Core::Classification::Address::Settlement < H24Core::ApplicationRecord
  include H24Core::HstoreTranslated

  self.table_name = 'settlements'

  belongs_to :region, class_name: 'H24Core::Classification::Address::Region', optional: true, inverse_of: :settlements

  has_many :city_districts, class_name: 'H24Core::Classification::Address::CityDistrict', inverse_of: :settlement,
                            dependent: nil

  hstore_translated :title, :title_translations

  def center
    [ latitude, longitude ] if latitude && longitude
  end
end

# == Schema Information
#
# Table name: settlements
#
#  id                   :bigint           not null, primary key
#  koatuu               :string
#  latitude             :float
#  longitude            :float
#  mountain_group       :boolean
#  priority             :integer
#  title_translations   :hstore
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  api_id               :string
#  district_id          :integer
#  parent_settlement_id :integer
#  region_id            :integer
#  settlement_type_id   :integer
#
# Indexes
#
#  index_settlements_on_api_id                (api_id) UNIQUE
#  index_settlements_on_district_id           (district_id)
#  index_settlements_on_parent_settlement_id  (parent_settlement_id)
#  index_settlements_on_region_id             (region_id)
#  index_settlements_on_settlement_type_id    (settlement_type_id)
#
