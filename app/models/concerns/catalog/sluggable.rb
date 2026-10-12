# frozen_string_literal: true

module Catalog::Sluggable
  extend ActiveSupport::Concern

  FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  MAX_LENGTH = 100

  included do
    has_many :seo_redirects, class_name: 'Seo::Redirect', as: :redirectable, inverse_of: :redirectable,
                             dependent: :delete_all

    validates :slug, presence: true, uniqueness: true, length: { maximum: MAX_LENGTH }, format: { with: FORMAT }
    validate :slug_is_not_redirected_elsewhere, if: :slug_changed?

    before_validation :assign_slug, on: :create
    # The slug is part of public URLs: a rename keeps it, and only an explicit change moves it, leaving a redirect.
    after_update :redirect_previous_slug, if: :saved_change_to_slug?
  end

  private

  def assign_slug
    return if slug.present? || name_uk.blank?

    self.slug = Catalog::Slugs::Generator.call(name_uk, scope: self.class)
  end

  # A slug that still redirects to another record belongs to that record until the redirect expires.
  def slug_is_not_redirected_elsewhere
    held = Seo::Redirect.where(redirectable_type: self.class.polymorphic_name, slug:)
    held = held.where.not(redirectable_id: id) if persisted?
    errors.add(:slug, :taken) if held.exists?
  end

  def redirect_previous_slug
    previous, current = saved_change_to_slug
    seo_redirects.where(slug: [ previous, current ]).delete_all
    seo_redirects.create!(slug: previous)
  end
end
