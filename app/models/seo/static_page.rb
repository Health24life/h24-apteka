# frozen_string_literal: true

# A page of the section that an editor writes in the admin: its name, address, text and whether it is out. The home
# page is one of them only for its meta tags: the front draws it, and its address is fixed.
class Seo::StaticPage < ApplicationRecord
  include Translatable
  include Catalog::Sluggable
  include Seo::SanitizedHtml
  include Seo::PageHistory

  HOME = 'home'

  translatable :name
  translatable :content, backend: :table
  sanitized_html :content
  page_history only: %i[name slug published]
  history_owner
  translations_history owner: ->(translation) { translation.translated_model }

  has_one :seo_override, class_name: 'Seo::Override', as: :target, inverse_of: :target, dependent: :destroy

  validates :name_uk, presence: true
  validates :key, inclusion: { in: [ HOME ] }, uniqueness: true, allow_nil: true

  before_destroy :keep_home

  scope :published, -> { where(published: true) }
  scope :pages, -> { where(key: nil) }
  scope :name_cont, ->(text) { where("seo_static_pages.name->>'uk' ILIKE ?", "%#{sanitize_sql_like(text.to_s)}%") }

  def self.home = find_by(key: HOME)

  def home? = key == HOME

  def own_slug? = !home?

  # The state of its page while it is off the section, or nil while it is on: the home page always is.
  def hidden_status = (404 unless home? || published?)

  private

  def reserved_slugs = Seo::Pages::Path::SEGMENTS.values

  def keep_home
    return unless home?

    errors.add(:base, :home_required)
    throw :abort
  end
end

# == Schema Information
#
# Table name: seo_static_pages
#
#  id         :bigint           not null, primary key
#  key        :string
#  name       :jsonb            not null
#  published  :boolean          default(FALSE), not null
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_seo_static_pages_on_key   (key) UNIQUE
#  index_seo_static_pages_on_slug  (slug) UNIQUE
#
# Check Constraints
#
#  seo_static_pages_slug_check  (key::text = 'home'::text AND slug IS NULL OR key IS NULL AND slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#
