# app/models/catalog/atc_class.rb
# frozen_string_literal: true

class Catalog::AtcClass < ApplicationRecord
  include Catalog::ProviderLinked
  include Translatable

  translatable :name

  belongs_to :parent, class_name: 'Catalog::AtcClass', optional: true, inverse_of: :children

  has_many :children, class_name: 'Catalog::AtcClass', foreign_key: :parent_id, inverse_of: :parent,
                      dependent: :restrict_with_exception

  validates :atc_code, presence: true
  validate :parent_is_not_self

  scope :roots, -> { where(parent_id: nil) }

  private

  def parent_is_not_self
    errors.add(:parent, :invalid) if parent_id.present? && parent_id == id
  end
end

# == Schema Information
#
# Table name: catalog_atc_classes
#
#  id         :bigint           not null, primary key
#  atc_code   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#
# Indexes
#
#  index_catalog_atc_classes_on_parent_id  (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => catalog_atc_classes.id)
#
# Check Constraints
#
#  catalog_atc_classes_parent_check  (parent_id IS NULL OR parent_id <> id)
#
