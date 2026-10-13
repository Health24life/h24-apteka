# frozen_string_literal: true

FactoryBot.define do
  factory :seo_override, class: 'Seo::Override' do
    target { association :catalog_goods }
  end
end
