# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_group_category, class: 'Catalog::GoodsGroupCategory' do
    goods_group factory: %i[catalog_goods_group]
    category factory: %i[catalog_category]
  end
end

# == Schema Information
#
# Table name: catalog_goods_group_categories
#
#  id             :bigint           not null, primary key
#  is_primary     :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  category_id    :bigint           not null
#  goods_group_id :bigint           not null
#
# Indexes
#
#  index_catalog_goods_group_categories_on_category_id  (category_id)
#  index_catalog_goods_group_categories_primary         (goods_group_id) UNIQUE WHERE is_primary
#  index_catalog_goods_group_categories_uniqueness      (goods_group_id,category_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => catalog_categories.id)
#  fk_rails_...  (goods_group_id => catalog_goods_groups.id) ON DELETE => cascade
#
