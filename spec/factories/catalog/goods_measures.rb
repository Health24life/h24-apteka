# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_measure, class: 'Catalog::Goods::Measure' do
    name_uk { 'Упаковка' }
  end
end

# == Schema Information
#
# Table name: catalog_goods_measures
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
