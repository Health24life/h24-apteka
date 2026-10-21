# frozen_string_literal: true

FactoryBot.define do
  factory :favorite_drugstore, class: 'Favorite::Drugstore' do
    user { association :h24_core_user, strategy: :create }
    drugstore { association :catalog_drugstore, strategy: :create }
  end
end
