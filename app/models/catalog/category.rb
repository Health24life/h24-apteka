# frozen_string_literal: true

class Catalog::Category < ApplicationRecord
  include Catalog::ProviderLinked
  include Catalog::Tree
  include Translatable
  include Catalog::Sluggable

  translatable :name

  has_many :goods_group_categories, class_name: 'Catalog::GoodsGroupCategory', inverse_of: :category,
                                    dependent: :restrict_with_exception
  has_many :goods_groups, through: :goods_group_categories

  validates :name_uk, presence: true
end

# == Schema Information
#
# Table name: catalog_categories
#
#  id         :bigint           not null, primary key
#  depth      :integer          default(0), not null
#  name       :jsonb            not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#
# Indexes
#
#  index_catalog_categories_on_parent_id  (parent_id)
#  index_catalog_categories_on_slug       (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => catalog_categories.id)
#
# Check Constraints
#
#  catalog_categories_depth_check   (depth >= 0)
#  catalog_categories_parent_check  (parent_id IS NULL OR parent_id <> id)
#  catalog_categories_slug_check    (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#
