# frozen_string_literal: true

class Catalog::Category < ApplicationRecord
  include Catalog::ProviderLinked
  include Catalog::Tree
  include Translatable

  translatable :name

  has_many :goods_group_categories, class_name: 'Catalog::GoodsGroupCategory', inverse_of: :category,
                                    dependent: :restrict_with_exception
  has_many :goods_groups, through: :goods_group_categories

  validates :name_uk, presence: true
  validates :slug, presence: true, uniqueness: true, length: { maximum: Catalog::SLUG_MAX_LENGTH },
                   format: { with: Catalog::SLUG_FORMAT }
  validates :depth, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :slug_is_unchanged, on: :update

  before_validation :assign_slug, on: :create

  # The address is part of public URLs, so it is fixed once saved. attr_readonly is not used because its
  # write_attribute override takes two arguments and breaks the three-argument call from globalize accessors.
  def slug=(value)
    raise ActiveRecord::ReadonlyAttributeError, :slug if persisted?

    super
  end

  private

  def assign_slug
    return if slug.present? || name_uk.blank?

    self.slug = Catalog::SlugGenerator.call(name_uk, scope: self.class)
  end

  def slug_is_unchanged
    errors.add(:slug, :invalid) if slug_changed?
  end
end

# == Schema Information
#
# Table name: catalog_categories
#
#  id         :bigint           not null, primary key
#  depth      :integer          default(0), not null
#  name       :string
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
