# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_name, class: 'Catalog::GoodsName' do
    sequence(:name) { |n| "Trade name #{n}" }
  end
end

# == Schema Information
#
# Table name: catalog_goods_names
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
