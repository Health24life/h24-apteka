# frozen_string_literal: true

class Catalog::Goods::Group::Category < ApplicationRecord
  belongs_to :goods_group, class_name: 'Catalog::Goods::Group', inverse_of: :goods_group_categories
  belongs_to :category, class_name: 'Catalog::Category', inverse_of: :goods_group_categories

  validates :category_id, uniqueness: { scope: :goods_group_id }
  validates :is_primary, uniqueness: { scope: :goods_group_id }, if: :is_primary?
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
