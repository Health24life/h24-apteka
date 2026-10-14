# frozen_string_literal: true

# Texts and robots an operator set by hand for one page. A filled text wins over the template; an empty one leaves the
# template's. It belongs to the record, not to its slug, so a new slug keeps it.
class Seo::Override < ApplicationRecord
  include Translatable
  include Seo::SanitizedHtml
  include Seo::PageHistory

  # The records that have a page of their own. A new kind of page is added here; the database does not list them.
  TARGET_TYPES = %w[Catalog::Goods Catalog::Category Seo::StaticPage Seo::Filter].freeze
  TEXTS = %i[title description h1].freeze

  # `auto` follows the rules of the page; `index` and `noindex` force the answer.
  enum :robots, { auto: 'auto', index: 'index', noindex: 'noindex' }, validate: true, prefix: :robots

  # Short texts live in jsonb columns of the row, the long SEO text in a translations table.
  translatable(*TEXTS)
  translatable :seo_text, backend: :table
  sanitized_html :seo_text
  page_history owner: ->(override) { override.target }
  translations_history owner: ->(translation) { translation.translated_model&.target }

  belongs_to :target, polymorphic: true, inverse_of: :seo_override

  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :target_id, uniqueness: { scope: :target_type }
  validates(*TEXTS.map { :"#{it}_uk" }, :seo_text_uk, neutral_wording: true)
end

# == Schema Information
#
# Table name: seo_overrides
#
#  id          :bigint           not null, primary key
#  description :jsonb            not null
#  h1          :jsonb            not null
#  robots      :string           default("auto"), not null
#  target_type :string           not null
#  title       :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  target_id   :bigint           not null
#
# Indexes
#
#  index_seo_overrides_on_target  (target_type,target_id) UNIQUE
#
# Check Constraints
#
#  seo_overrides_robots_check  (robots::text = ANY (ARRAY['auto'::character varying, 'index'::character varying, 'noindex'::character varying]::text[]))
#
