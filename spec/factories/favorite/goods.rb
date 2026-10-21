# frozen_string_literal: true

FactoryBot.define do
  factory :favorite_goods, class: 'Favorite::Goods' do
    user_id { 42 }
    goods { association :catalog_goods, strategy: :create }
  end
end
