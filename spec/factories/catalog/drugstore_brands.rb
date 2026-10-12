# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_drugstore_brand, class: 'Catalog::Drugstore::Brand' do
    sequence(:name) { |n| "Brand #{n}" }
  end
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
