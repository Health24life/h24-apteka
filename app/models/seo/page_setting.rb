# frozen_string_literal: true

# Texts an operator set by hand for the page of one SKU or category. A filled field wins over the template; an empty
# one leaves the template's. It belongs to the record, not to its slug, so a new slug keeps it.
class Seo::PageSetting < ApplicationRecord
  SETTABLE_TYPES = %w[Catalog::Goods Catalog::Category].freeze

  belongs_to :settable, polymorphic: true, inverse_of: :seo_page_setting

  normalizes :title, :description, :h1, :seo_text, with: -> { it.strip.presence }

  validates :settable_type, inclusion: { in: SETTABLE_TYPES }
  validates :settable_id, uniqueness: { scope: :settable_type }
  validates :title, :description, :h1, :seo_text, neutral_wording: true
end

# == Schema Information
#
# Table name: seo_page_settings
#
#  id            :bigint           not null, primary key
#  description   :string
#  h1            :string
#  seo_text      :text
#  settable_type :string           not null
#  title         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  settable_id   :bigint           not null
#
# Indexes
#
#  index_seo_page_settings_on_settable  (settable_type,settable_id) UNIQUE
#
# Check Constraints
#
#  seo_page_settings_type_check  (settable_type::text = ANY (ARRAY['Catalog::Goods'::character varying, 'Catalog::Category'::character varying]::text[]))
#
