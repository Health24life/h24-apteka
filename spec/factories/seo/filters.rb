# frozen_string_literal: true

FactoryBot.define do
  factory :seo_filter, class: 'Seo::Filter' do
    sequence(:name_uk) { |n| "Добірка #{n}" }

    trait :published do
      published { true }
      params { { 'form_id' => [ create(:catalog_goods_form).id ] } }
    end
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
