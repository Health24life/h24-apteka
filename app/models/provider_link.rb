# frozen_string_literal: true

class ProviderLink < ApplicationRecord
  LINKABLE_TYPES = %w[
    Catalog::DrugstoreBrand Catalog::GoodsForm Catalog::GoodsMeasure Catalog::GoodsPriceGroup
    Catalog::GoodsTemperatureMode Catalog::GoodsRestriction Catalog::Category Catalog::Producer
    Catalog::GoodsName Catalog::AtcClass Catalog::GoodsGroup Catalog::Goods Catalog::Drugstore
  ].freeze

  belongs_to :provider, inverse_of: :provider_links
  belongs_to :linkable, polymorphic: true, inverse_of: :provider_links

  validates :linkable_type, inclusion: { in: LINKABLE_TYPES }
  validates :external_id, presence: true, uniqueness: { scope: %i[provider_id linkable_type] }
  validates :linkable_id, uniqueness: { scope: %i[provider_id linkable_type] }
  validates :synced_at, presence: true
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
