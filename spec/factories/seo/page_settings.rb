# frozen_string_literal: true

FactoryBot.define do
  factory :seo_page_setting, class: 'Seo::PageSetting' do
    settable { association :catalog_goods }
  end
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
