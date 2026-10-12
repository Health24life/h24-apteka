# frozen_string_literal: true

class Catalog::Drugstore::Brand < ApplicationRecord
  include Catalog::ProviderLinked

  has_many :drugstores, class_name: 'Catalog::Drugstore', inverse_of: :brand,
                        dependent: :restrict_with_exception

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
