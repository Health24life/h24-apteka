# frozen_string_literal: true

FactoryBot.define do
  factory :seo_override, class: 'Seo::Override' do
    target { association :catalog_goods }
  end
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
