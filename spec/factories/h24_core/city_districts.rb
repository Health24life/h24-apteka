# frozen_string_literal: true

FactoryBot.define do
  factory :h24_core_city_district, class: 'H24Core::Classification::Address::CityDistrict' do
    title_translations { { 'uk' => 'Шевченківський' } }
  end
end
