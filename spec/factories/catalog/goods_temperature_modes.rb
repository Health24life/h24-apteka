# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_temperature_mode, class: 'Catalog::Goods::TemperatureMode' do
    name_uk { 'Кімнатна' }
  end
end

# == Schema Information
#
# Table name: catalog_goods_temperature_modes
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
