# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_price_group, class: 'Catalog::Goods::PriceGroup' do
    name_uk { 'Група 1' }
  end
end

# == Schema Information
#
# Table name: catalog_goods_price_groups
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
