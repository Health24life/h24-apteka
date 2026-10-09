# frozen_string_literal: true

FactoryBot.define do
  factory :h24_core_inn, class: 'H24Core::Medication::Inn' do
    sequence(:title_original) { |n| "Inn #{n}" }
    title_translations { { 'uk' => 'МНН' } }
    in_ehealth { false }
  end
end
