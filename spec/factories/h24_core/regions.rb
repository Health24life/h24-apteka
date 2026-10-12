# frozen_string_literal: true

FactoryBot.define do
  factory :h24_core_region, class: 'H24Core::Classification::Address::Region' do
    title_translations { { 'uk' => 'Київська область' } }
  end
end
