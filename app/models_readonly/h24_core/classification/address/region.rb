# frozen_string_literal: true

class H24Core::Classification::Address::Region < H24Core::ApplicationRecord
  include H24Core::HstoreTranslated

  self.table_name = 'regions'

  has_many :settlements, class_name: 'H24Core::Classification::Address::Settlement', inverse_of: :region,
                         dependent: nil

  hstore_translated :title, :title_translations
end

# == Schema Information
#
# Table name: regions
#
#  id                 :bigint           not null, primary key
#  koatuu             :string
#  latitude           :float
#  longitude          :float
#  title_translations :hstore
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  api_id             :string
#  country_id         :bigint
#
# Indexes
#
#  index_regions_on_api_id      (api_id) UNIQUE
#  index_regions_on_country_id  (country_id)
#
