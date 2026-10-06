# frozen_string_literal: true

class H24Core::Classification::Address::CityDistrict < H24Core::ApplicationRecord
  include H24Core::HstoreTranslated

  self.table_name = 'city_districts'

  belongs_to :settlement, class_name: 'H24Core::Classification::Address::Settlement', optional: true,
                          inverse_of: :city_districts

  hstore_translated :title, :title_translations
end

# == Schema Information
#
# Table name: city_districts
#
#  id                 :bigint           not null, primary key
#  koatuu             :string
#  title_translations :hstore
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  settlement_id      :bigint
#
# Indexes
#
#  index_city_districts_on_settlement_id  (settlement_id)
#
