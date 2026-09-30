# app/models/catalog/category.rb
# frozen_string_literal: true

class Catalog::Category < ApplicationRecord
  include Catalog::ProviderLinked
  include Translatable

  translatable :name

  belongs_to :parent, class_name: 'Catalog::Category', optional: true, inverse_of: :children

  has_many :children, class_name: 'Catalog::Category', foreign_key: :parent_id, inverse_of: :parent,
                      dependent: :restrict_with_exception
  has_many :goods_group_categories, class_name: 'Catalog::GoodsGroupCategory', inverse_of: :category,
                                    dependent: :restrict_with_exception
  has_many :goods_groups, through: :goods_group_categories

  validates :name_uk, presence: true
  validates :slug, presence: true, uniqueness: true, length: { maximum: Catalog::SLUG_MAX_LENGTH },
                   format: { with: Catalog::SLUG_FORMAT }
  validates :depth, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parent_is_not_self

  before_validation :assign_slug, on: :create

  scope :roots, -> { where(parent_id: nil) }

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

  def parent_is_not_self
    errors.add(:parent, :invalid) if parent_id.present? && parent_id == id
  end
end

# == Schema Information
#
# Table name: catalog_categories
#
#  id         :bigint           not null, primary key
#  depth      :integer          default(0), not null
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
#
