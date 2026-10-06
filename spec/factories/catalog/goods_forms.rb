# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_form, class: 'Catalog::GoodsForm' do
    name_uk { 'Таблетки' }
  end
end

# == Schema Information
#
# Table name: catalog_goods_forms
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
