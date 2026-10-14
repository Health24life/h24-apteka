# frozen_string_literal: true

module Catalog::Sluggable
  extend ActiveSupport::Concern

  FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  MAX_LENGTH = 100

  included do
    # destroy, not delete_all: the cache drops the redirects of a record that is gone.
    has_many :seo_redirects, class_name: 'Seo::Redirect', as: :redirectable, inverse_of: :redirectable,
                             dependent: :destroy

    validates :slug, presence: true, uniqueness: true, length: { maximum: MAX_LENGTH }, format: { with: FORMAT },
                     if: :own_slug?
    validate :slug_is_not_redirected_elsewhere, :slug_is_not_reserved, if: %i[own_slug? slug_changed?]

    before_validation :assign_slug, on: :create, if: :own_slug?
    # The slug is part of public URLs: a rename keeps it, and only an explicit change moves it, leaving a redirect.
    after_update :redirect_previous_slug, if: :saved_change_to_slug?
  end

  # A record whose page has a fixed address, like the home page, has no slug of its own.
  def own_slug? = true

  private

  # Slugs the front's own routes take, so a page with one of them would never be reached.
  def reserved_slugs = []

  def assign_slug
    return if slug.present? || name_uk.blank?

    self.slug = Catalog::Slugs::Generator.call(name_uk, scope: self.class, reserved: reserved_slugs.to_set)
  end

  def slug_is_not_reserved
    errors.add(:slug, :reserved) if reserved_slugs.include?(slug)
  end

  # A slug of this kind of page that still redirects to another record, of any kind, belongs to that record until the
  # redirect expires.
  def slug_is_not_redirected_elsewhere
    held = Seo::Redirect.where(page_type: seo_page_type, slug:)
    held = held.where.not(redirectable: self) if persisted?
    errors.add(:slug, :held) if held.exists?
  end

  def redirect_previous_slug
    previous, current = saved_change_to_slug
    # destroy_all, not delete_all: the cache drops the redirect of a slug the record takes back.
    seo_redirects.where(page_type: seo_page_type, slug: [ previous, current ]).destroy_all
    # An editor may already lead the slug of a withdrawn record elsewhere; that choice stands.
    return if Seo::Redirect.exists?(page_type: seo_page_type, slug: previous)

    seo_redirects.create!(page_type: seo_page_type, slug: previous)
  end

  def seo_page_type = Seo::Redirect.page_type_for(self.class)
end
