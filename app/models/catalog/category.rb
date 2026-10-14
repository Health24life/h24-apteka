# frozen_string_literal: true

class Catalog::Category < ApplicationRecord
  include Catalog::ProviderLinked
  include Translatable
  include Catalog::Sluggable

  translatable :name

  # Save callbacks keep the hierarchy table, so a write past them (insert_all, upsert_all, update_all on parent_id)
  # has to be followed by rebuild!.
  has_closure_tree dependent: :restrict_with_exception

  has_many :goods_group_categories, class_name: 'Catalog::Goods::Group::Category', inverse_of: :category,
                                    dependent: :restrict_with_exception
  has_many :goods_groups, through: :goods_group_categories
  has_many :seo_templates, class_name: 'Seo::Template', inverse_of: :category, dependent: :delete_all
  has_one :seo_override, class_name: 'Seo::Override', as: :target, inverse_of: :target, dependent: :destroy

  validates :name_uk, presence: true

  # Categories whose branch, the category itself included, holds at least one SKU shown on the storefront.
  scope :with_shown_goods, lambda {
    where(<<~SQL.squish)
      EXISTS (
        SELECT 1 FROM catalog_category_hierarchies hierarchy
        JOIN catalog_goods_group_categories link ON link.category_id = hierarchy.descendant_id
        JOIN catalog_goods_groups goods_group ON goods_group.id = link.goods_group_id
          AND NOT goods_group.hidden AND NOT goods_group.withdrawn
        JOIN catalog_goods goods ON goods.goods_group_id = goods_group.id AND NOT goods.hidden AND NOT goods.withdrawn
        WHERE hierarchy.ancestor_id = catalog_categories.id
      )
    SQL
  }

  def shown_goods? = self.class.with_shown_goods.exists?(id)

  def branch_name = self_and_ancestors.to_a.reverse.map(&:name_uk).join(' › ')
end

# == Schema Information
#
# Table name: catalog_categories
#
#  id         :bigint           not null, primary key
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
#  catalog_categories_parent_check  (parent_id IS NULL OR parent_id <> id)
#  catalog_categories_slug_check    (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#
