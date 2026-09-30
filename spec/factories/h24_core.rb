# frozen_string_literal: true

FactoryBot.define do
  factory :h24_core_user, class: 'H24Core::User' do
    sequence(:email) { |n| "core-user#{n}@example.com" }
    sequence(:phone_number) { |n| "+38050#{format('%07d', n)}" }
    first_name { 'Anna' }
  end

  factory :h24_core_country, class: 'H24Core::Classification::Address::Country' do
    sequence(:code) { |n| "C#{n}" }
    title_translations { { 'uk' => 'Україна' } }
  end

  factory :h24_core_inn, class: 'H24Core::Medication::Inn' do
    sequence(:title_original) { |n| "Inn #{n}" }
    title_translations { { 'uk' => 'МНН' } }
    in_ehealth { false }
  end
end
