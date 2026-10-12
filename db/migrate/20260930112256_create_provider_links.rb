class CreateProviderLinks < ActiveRecord::Migration[8.1]
  LINKABLE_TYPES = %w[
    Catalog::Drugstore::Brand Catalog::Goods::Form Catalog::Goods::Measure Catalog::Goods::PriceGroup
    Catalog::Goods::TemperatureMode Catalog::Goods::Restriction Catalog::Category Catalog::Producer
    Catalog::Goods::Name Catalog::AtcClass Catalog::Goods::Group Catalog::Goods Catalog::Drugstore
  ].freeze

  def change
    create_table :provider_links do |t|
      t.references :provider, null: false, foreign_key: true, index: false
      t.string :linkable_type, null: false
      t.bigint :linkable_id, null: false
      t.string :external_id, null: false
      t.jsonb :attrs, null: false, default: {}
      t.datetime :synced_at, null: false

      t.timestamps
    end

    add_index :provider_links, %i[provider_id linkable_type external_id], unique: true,
                                                                          name: 'index_provider_links_on_provider_external_id'
    add_index :provider_links, %i[provider_id linkable_type linkable_id], unique: true,
                                                                          name: 'index_provider_links_on_provider_linkable'
    add_index :provider_links, %i[linkable_type linkable_id], name: 'index_provider_links_on_linkable'
    add_check_constraint :provider_links, "linkable_type IN (#{LINKABLE_TYPES.map { "'#{it}'" }.join(', ')})",
                         name: 'provider_links_linkable_type_check'
  end
end
