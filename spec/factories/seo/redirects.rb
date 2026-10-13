# frozen_string_literal: true

FactoryBot.define do
  factory :seo_redirect, class: 'Seo::Redirect' do
    redirectable { association :catalog_goods }
    page_type { Seo::Redirect.page_type_for(redirectable.class) }
    sequence(:slug) { |n| "old-slug-#{n}" }
  end
end

# == Schema Information
#
# Table name: seo_redirects
#
#  id                :bigint           not null, primary key
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
#  seo_redirects_page_type_check  (page_type::text = ANY (ARRAY['goods'::character varying, 'category'::character varying]::text[]))
#  seo_redirects_slug_check       (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#  seo_redirects_type_check       (redirectable_type::text = ANY (ARRAY['Catalog::Goods'::character varying, 'Catalog::Category'::character varying]::text[]))
#
