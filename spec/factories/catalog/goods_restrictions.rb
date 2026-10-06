# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_restriction, class: 'Catalog::GoodsRestriction' do
    name_uk { 'Без обмежень' }
  end
end

# == Schema Information
#
# Table name: catalog_goods_restrictions
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
