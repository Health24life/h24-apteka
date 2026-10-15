# frozen_string_literal: true

# A named selection of goods that is a page of its own: the parameters of the catalog search a buyer could set, kept so
# the page shows what the search gives for them. A removed filter stays, so its address answers 410 and no other filter
# takes it.
class Seo::Filter < ApplicationRecord
  include Translatable
  include Catalog::Sluggable
  include Seo::PageHistory

  # The parameters of the catalog search a filter may keep, with the records their ids point at, in the order the page
  # shows them. The catalog search takes the same keys.
  PARAMS = {
    'category_id' => Catalog::Category,
    'form_id' => Catalog::Goods::Form,
    'producer_id' => Catalog::Producer,
    **Catalog::Goods::RESTRICTIONS.to_h { [ "#{it}_id", Catalog::Goods::Restriction ] }
  }.freeze

  enum :sort_order, { name: 'name', newest: 'newest' }, validate: true, prefix: :sorted_by
  # A public selection of prescription medicines may count as their advertising, so a filter takes only goods without
  # a prescription unless the lawyer agreed otherwise.
  enum :recipe_scope, { otc: 'otc', rx: 'rx', any: 'any' }, validate: true, prefix: :recipe

  translatable :name
  page_history
  history_owner

  # A form sends every parameter, blank ones too, with ids as strings. Anything else stays for the validator to refuse.
  normalizes :params, with: lambda { |params|
    next params unless params.respond_to?(:each_pair)

    # @type var kept: Hash[String, untyped]
    kept = {}
    params.each_pair do |key, ids|
      ids = ids.compact_blank.map { it.is_a?(String) && it.match?(/\A\d+\z/) ? it.to_i : it } if ids.is_a?(Array)
      kept[key.to_s] = ids if ids.present?
    end
    kept
  }

  belongs_to :category, class_name: 'Catalog::Category', optional: true, inverse_of: :seo_filters
  has_one :seo_override, class_name: 'Seo::Override', as: :target, inverse_of: :target, dependent: :destroy

  validates :name_uk, presence: true, neutral_wording: true
  validates :params, seo_filter_params: true
  validates :params, presence: true, if: :published?
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :removed_is_unpublished

  scope :listed, -> { where(published: true, removed_at: nil) }

  def removed? = removed_at.present?

  # The state of its page while it is off the section, or nil while it is published: gone for good once removed.
  def hidden_status
    return 410 if removed?

    404 unless published?
  end

  # Takes the filter off the section for good: the redirects to it go, and its own address answers 410.
  def remove!
    transaction do
      update!(published: false, removed_at: Time.current)
      seo_redirects.destroy_all
    end
  end

  # Brings a removed filter back as a draft. A redirect an editor set from its address leads to another page and holds
  # the address against the filter itself, so it goes first.
  def restore!
    transaction do
      Seo::Redirect.where(page_type: Seo::Redirect.page_type_for(self.class), slug:, manual: true).destroy_all
      update!(removed_at: nil)
    end
  end

  private

  def removed_is_unpublished
    errors.add(:published, :removed) if removed? && published?
  end
end

# == Schema Information
#
# Table name: seo_filters
#
#  id           :bigint           not null, primary key
#  name         :jsonb            not null
#  params       :jsonb            not null
#  position     :integer          default(0), not null
#  published    :boolean          default(FALSE), not null
#  recipe_scope :string           default("otc"), not null
#  removed_at   :datetime
#  slug         :string           not null
#  sort_order   :string           default("name"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  category_id  :bigint
#
# Indexes
#
#  index_seo_filters_listed   (category_id,position) WHERE (published AND (removed_at IS NULL))
#  index_seo_filters_on_slug  (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => catalog_categories.id)
#
# Check Constraints
#
#  seo_filters_position_check      ("position" >= 0)
#  seo_filters_recipe_scope_check  (recipe_scope::text = ANY (ARRAY['otc'::character varying, 'rx'::character varying, 'any'::character varying]::text[]))
#  seo_filters_removed_check       (removed_at IS NULL OR NOT published)
#  seo_filters_slug_check          (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#  seo_filters_sort_order_check    (sort_order::text = ANY (ARRAY['name'::character varying, 'newest'::character varying]::text[]))
#
