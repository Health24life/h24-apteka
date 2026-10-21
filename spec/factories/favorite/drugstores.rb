# frozen_string_literal: true

FactoryBot.define do
  factory :favorite_drugstore, class: 'Favorite::Drugstore' do
    user_id { 42 }
    drugstore { association :catalog_drugstore, strategy: :create }
  end
end
