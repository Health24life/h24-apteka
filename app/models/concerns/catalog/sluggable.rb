# frozen_string_literal: true

module Catalog::Sluggable
  extend ActiveSupport::Concern

  FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  MAX_LENGTH = 100

  included do
    validates :slug, presence: true, uniqueness: true, length: { maximum: MAX_LENGTH }, format: { with: FORMAT }
    validate :slug_is_unchanged, on: :update

    before_validation :assign_slug, on: :create
  end

  # The slug is part of public URLs, so it is fixed once saved. attr_readonly is not used because it also
  # refuses update_column, which writes past the model on purpose.
  def slug=(value)
    raise ActiveRecord::ReadonlyAttributeError, :slug if persisted?

    super
  end

  private

  def assign_slug
    return if slug.present? || name_uk.blank?

    self.slug = Catalog::Slugs::Generator.call(name_uk, scope: self.class)
  end

  def slug_is_unchanged
    errors.add(:slug, :invalid) if slug_changed?
  end
end
