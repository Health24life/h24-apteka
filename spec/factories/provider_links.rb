# frozen_string_literal: true

FactoryBot.define do
  factory :provider_link do
    provider
    linkable factory: :catalog_drugstore_brand
    sequence(:external_id, &:to_s)
    synced_at { Time.current }
  end
end

# == Schema Information
#
# Table name: provider_links
#
#  id            :bigint           not null, primary key
#  attrs         :jsonb            not null
#  linkable_type :string           not null
#  synced_at     :datetime         not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  external_id   :string           not null
#  linkable_id   :bigint           not null
#  provider_id   :bigint           not null
#
# Indexes
#
#  index_provider_links_on_linkable              (linkable_type,linkable_id)
#  index_provider_links_on_provider_external_id  (provider_id,linkable_type,external_id) UNIQUE
#  index_provider_links_on_provider_linkable     (provider_id,linkable_type,linkable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (provider_id => providers.id)
#
# Check Constraints
#
#  provider_links_linkable_type_check  (linkable_type::text = ANY (ARRAY['Catalog::DrugstoreBrand'::character varying, 'Catalog::GoodsForm'::character varying, 'Catalog::GoodsMeasure'::character varying, 'Catalog::GoodsPriceGroup'::character varying, 'Catalog::GoodsTemperatureMode'::character varying, 'Catalog::GoodsRestriction'::character varying, 'Catalog::Category'::character varying, 'Catalog::Producer'::character varying, 'Catalog::GoodsName'::character varying, 'Catalog::AtcClass'::character varying, 'Catalog::GoodsGroup'::character varying, 'Catalog::Goods'::character varying, 'Catalog::Drugstore'::character varying]::text[]))
#
