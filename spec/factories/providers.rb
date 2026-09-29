# frozen_string_literal: true

FactoryBot.define do
  factory :provider do
    sequence(:code) { |n| "provider_#{n}" }
    name { 'Provider' }
    kind { 'external' }

    trait :own do
      kind { 'own' }
    end
  end
end

# == Schema Information
#
# Table name: providers
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  code              :string           not null
#  kind              :string           not null
#  name              :string           not null
#  supports_delivery :boolean          default(FALSE), not null
#  supports_e_recipe :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_providers_on_code  (code) UNIQUE
#
