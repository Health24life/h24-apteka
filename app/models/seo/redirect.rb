# frozen_string_literal: true

# An old slug of a record that the front still answers with a permanent redirect. It points at the record, not at the
# new slug, so the old one always leads to the slug the record has now and no chain builds up over several changes.
class Seo::Redirect < ApplicationRecord
  REDIRECTABLE_TYPES = %w[Catalog::Goods Catalog::Category].freeze

  belongs_to :redirectable, polymorphic: true, inverse_of: :seo_redirects

  validates :redirectable_type, inclusion: { in: REDIRECTABLE_TYPES }
  validates :slug, presence: true, length: { maximum: Catalog::Sluggable::MAX_LENGTH },
                   format: { with: Catalog::Sluggable::FORMAT }, uniqueness: { scope: :redirectable_type }

  # The endpoint reads redirects from the cache, so it follows each committed change of the table.
  after_create_commit :cache
  after_destroy_commit :uncache

  scope :active, -> { where(created_at: Seo::Config.current.redirect_ttl.ago..) }
  scope :expired, -> { where(created_at: ...Seo::Config.current.redirect_ttl.ago) }

  private

  def cache = Seo::Redirects::Cache.write(self)

  def uncache = Seo::Redirects::Cache.delete(self)
end

# == Schema Information
#
# Table name: seo_redirects
#
#  id                :bigint           not null, primary key
#  redirectable_type :string           not null
#  slug              :string           not null
#  created_at        :datetime         not null
#  redirectable_id   :bigint           not null
#
# Indexes
#
#  index_seo_redirects_on_redirectable_type_and_redirectable_id  (redirectable_type,redirectable_id)
#  index_seo_redirects_on_redirectable_type_and_slug             (redirectable_type,slug) UNIQUE
#
# Check Constraints
#
#  seo_redirects_slug_check  (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#  seo_redirects_type_check  (redirectable_type::text = ANY (ARRAY['Catalog::Goods'::character varying, 'Catalog::Category'::character varying]::text[]))
#
