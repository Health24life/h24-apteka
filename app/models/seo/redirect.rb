# frozen_string_literal: true

# An old slug of a kind of page that the front still answers with a permanent redirect. It points at a record, not at
# the record's new slug, so the old one always leads to the slug the record has now and no chain builds up over several
# changes. The kind of page and the kind of record are kept apart: an old slug of a product page may lead to a category.
class Seo::Redirect < ApplicationRecord
  include Seo::PageHistory

  # The kind of page whose slugs a record with a slug takes.
  PAGE_TYPES = {
    'Catalog::Goods' => 'goods', 'Catalog::Category' => 'category', 'Seo::StaticPage' => 'static',
    'Seo::Filter' => 'filter'
  }.freeze
  REDIRECTABLE_TYPES = %w[Catalog::Goods Catalog::Category Seo::StaticPage Seo::Filter].freeze

  belongs_to :redirectable, polymorphic: true, inverse_of: :seo_redirects
  # The cleanup removes expired redirects with delete_all, so they leave no history.
  page_history owner: ->(redirect) { redirect.redirectable }

  validates :page_type, inclusion: { in: PAGE_TYPES.values }
  validates :redirectable_type, inclusion: { in: REDIRECTABLE_TYPES }
  validates :slug, presence: true, length: { maximum: Catalog::Sluggable::MAX_LENGTH },
                   format: { with: Catalog::Sluggable::FORMAT }, uniqueness: { scope: :page_type }

  # The endpoint reads redirects from the cache, so it follows each committed change of the table; an editor may lead
  # a redirect to another page.
  after_commit :cache, on: %i[create update]
  after_destroy_commit :uncache

  scope :active, -> { where(created_at: Seo::Config.current.redirect_ttl.ago..) }
  scope :expired, -> { where(created_at: ...Seo::Config.current.redirect_ttl.ago) }

  def self.page_type_for(record_class) = PAGE_TYPES.fetch(record_class.polymorphic_name)

  private

  def cache = Seo::Redirects::Cache.write(self)

  def uncache = Seo::Redirects::Cache.delete(self)
end

# == Schema Information
#
# Table name: seo_redirects
#
#  id                :bigint           not null, primary key
#  manual            :boolean          default(FALSE), not null
#  page_type         :string           not null
#  redirectable_type :string           not null
#  slug              :string           not null
#  created_at        :datetime         not null
#  redirectable_id   :bigint           not null
#
# Indexes
#
#  index_seo_redirects_on_page_type_and_slug                     (page_type,slug) UNIQUE
#  index_seo_redirects_on_redirectable_type_and_redirectable_id  (redirectable_type,redirectable_id)
#
# Check Constraints
#
#  seo_redirects_page_type_check  (page_type::text = ANY (ARRAY['goods'::character varying, 'category'::character varying, 'static'::character varying, 'filter'::character varying]::text[]))
#  seo_redirects_slug_check       (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#  seo_redirects_type_check       (redirectable_type::text = ANY (ARRAY['Catalog::Goods'::character varying, 'Catalog::Category'::character varying, 'Seo::StaticPage'::character varying, 'Seo::Filter'::character varying]::text[]))
#
