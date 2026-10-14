# frozen_string_literal: true

FactoryBot.define do
  factory :seo_template, class: 'Seo::Template' do
    page_type { 'goods' }
    title { '{name} {dosage} — інструкція' }
    description { '{name}: склад, показання, протипоказання' }
    h1 { '{name}' }
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
#  seo_templates_page_type_check  (page_type::text = ANY (ARRAY['home'::character varying, 'category'::character varying, 'goods'::character varying, 'cart'::character varying, 'order'::character varying, 'static'::character varying, 'filter'::character varying]::text[]))
#  seo_templates_recipe_check     (is_recipe IS NULL OR page_type::text = 'goods'::text)
#
