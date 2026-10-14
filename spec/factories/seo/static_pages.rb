# frozen_string_literal: true

FactoryBot.define do
  factory :seo_static_page, class: 'Seo::StaticPage' do
    sequence(:name_uk) { |n| "Сторінка #{n}" }
    content_uk { '<p>Бронювання без передоплати.</p>' }

    trait :published do
      published { true }
    end

    trait :home do
      key { Seo::StaticPage::HOME }
      name_uk { 'Головна' }
      content_uk { nil }
    end
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
