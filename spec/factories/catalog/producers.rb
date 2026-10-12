# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_producer, class: 'Catalog::Producer' do
    sequence(:name) { |n| "Producer #{n}" }
  end
end

# == Schema Information
#
# Table name: catalog_producers
#
#  id           :bigint           not null, primary key
#  country      :string
#  country_code :string(2)
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Check Constraints
#
#  catalog_producers_country_code_check  (country_code IS NULL OR country_code::text ~ '^[A-Z]{2}$'::text)
#
