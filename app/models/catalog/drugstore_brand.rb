# frozen_string_literal: true

class Catalog::DrugstoreBrand < ApplicationRecord
  include Catalog::ProviderLinked

  validates :name, presence: true
end

# == Schema Information
#
# Table name: catalog_drugstore_brands
#
#  id         :bigint           not null, primary key
#  image_path :string
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
