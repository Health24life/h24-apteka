# spec/factories/catalog/atc_classes.rb
# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_atc_class, class: 'Catalog::AtcClass' do
    sequence(:atc_code) { |n| "N#{format('%02d', n % 100)}" }
  end
end

# == Schema Information
#
# Table name: catalog_atc_classes
#
#  id         :bigint           not null, primary key
#  atc_code   :string           not null
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#
# Indexes
#
#  index_catalog_atc_classes_on_parent_id  (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => catalog_atc_classes.id)
#
# Check Constraints
#
#  catalog_atc_classes_parent_check  (parent_id IS NULL OR parent_id <> id)
#
