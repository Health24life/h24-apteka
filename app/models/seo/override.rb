# frozen_string_literal: true

# Texts and robots an operator set by hand for one page. A filled text wins over the template; an empty one leaves the
# template's. It belongs to the record, not to its slug, so a new slug keeps it.
class Seo::Override < ApplicationRecord
  include Translatable

  # The records that have a page of their own. A new kind of page is added here; the database does not list them.
  TARGET_TYPES = %w[Catalog::Goods Catalog::Category].freeze

  # Short texts live in jsonb columns of the row, the long SEO text in a translations table.
  translatable :title, :description, :h1
  translatable :seo_text, backend: :table

  # `auto` follows the rules of the page; `index` and `noindex` force the answer.
  enum :robots, { auto: 'auto', index: 'index', noindex: 'noindex' }, validate: true, prefix: :robots

  belongs_to :target, polymorphic: true, inverse_of: :seo_override

  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :target_id, uniqueness: { scope: :target_type }
  validates :title_uk, :description_uk, :h1_uk, :seo_text_uk, neutral_wording: true
end
