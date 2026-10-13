# frozen_string_literal: true

# Title, description and H1 of a kind of page, with placeholders filled from the record. A template may narrow down to a
# branch of the catalog and, for a product, to prescription goods; the narrowest one that fits a page applies.
class Seo::Template < ApplicationRecord
  include Translatable

  PLACEHOLDER = /\{([^{}]*)\}/
  PLACEHOLDERS = { 'goods' => %w[name inn producer form dosage], 'category' => %w[name] }.freeze
  TEXTS = %i[title description h1].freeze

  enum :page_type, { home: 'home', category: 'category', goods: 'goods', cart: 'cart', order: 'order' },
       validate: true, prefix: :for

  translatable(*TEXTS)

  belongs_to :category, class_name: 'Catalog::Category', optional: true, inverse_of: :seo_templates

  validates :title_uk, :description_uk, :h1_uk, presence: true, neutral_wording: true
  validates :page_type, uniqueness: { scope: %i[category_id is_recipe] }
  validates :category, absence: true, unless: -> { for_category? || for_goods? }
  validate :recipe_only_for_goods
  validate :placeholders_are_known

  before_destroy :keep_general

  def general? = category_id.nil? && is_recipe.nil?

  def placeholders = PLACEHOLDERS.fetch(page_type.to_s, [])

  private

  def recipe_only_for_goods
    errors.add(:is_recipe, :present) unless is_recipe.nil? || for_goods?
  end

  # Every language of a text is checked, not only the one being read.
  def placeholders_are_known
    TEXTS.each do |text|
      unknown = self[text].to_h.values.join(' ').scan(PLACEHOLDER).flatten.uniq - placeholders
      errors.add(text, :unknown_placeholders, placeholders: unknown.map { "{#{it}}" }.join(', ')) if unknown.any?
    end
  end

  # A page with no narrower template takes the general one, so a page type is never left without one.
  def keep_general
    return unless general?

    errors.add(:base, :general_template_required)
    throw :abort
  end
end

# == Schema Information
#
# Table name: seo_templates
#
#  id          :bigint           not null, primary key
#  description :jsonb            not null
#  h1          :jsonb            not null
#  is_recipe   :boolean
#  page_type   :string           not null
#  title       :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  category_id :bigint
#
# Indexes
#
#  index_seo_templates_on_category_id  (category_id)
#  index_seo_templates_uniqueness      (page_type,category_id,is_recipe) UNIQUE NULLS NOT DISTINCT
#
# Foreign Keys
#
#  fk_rails_...  (category_id => catalog_categories.id)
#
# Check Constraints
#
#  seo_templates_category_check   (category_id IS NULL OR (page_type::text = ANY (ARRAY['category'::character varying, 'goods'::character varying]::text[])))
#  seo_templates_page_type_check  (page_type::text = ANY (ARRAY['home'::character varying, 'category'::character varying, 'goods'::character varying, 'cart'::character varying, 'order'::character varying]::text[]))
#  seo_templates_recipe_check     (is_recipe IS NULL OR page_type::text = 'goods'::text)
#
