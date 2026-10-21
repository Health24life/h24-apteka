# frozen_string_literal: true

FactoryBot.define do
  factory :favorite_goods, class: 'Favorite::Goods' do
    user { association :h24_core_user, strategy: :create }
    goods { association :catalog_goods, strategy: :create }
  end
end
