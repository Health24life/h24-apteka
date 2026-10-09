# frozen_string_literal: true

FactoryBot.define do
  factory :h24_core_country, class: 'H24Core::Classification::Address::Country' do
    sequence(:code) { |n| "C#{n}" }
    title_translations { { 'uk' => 'Україна' } }
  end
end
