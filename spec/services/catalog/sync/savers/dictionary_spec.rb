# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Savers::Dictionary do
  subject(:saver) { described_class.new(Catalog::Sync::Linker.new(provider), tracker) }

  let(:provider) { create(:provider) }
  let(:tracker) { Catalog::Sync::RunTracker.start(provider:, kind: 'dictionaries') }
  let(:dictionaries) { Pharmapoint::Readers::Dictionaries.call(JSON.parse(pharmapoint_fixture('dictionaries'))) }

  it 'saves each dictionary in one insert', :aggregate_failures do
    statements = QueryLog.capture { saver.call(dictionaries) }

    expect(Catalog::Goods::Form.count).to eq(dictionaries.forms.size)
    expect(QueryLog.inserts_into(statements, 'catalog_goods_forms')).to eq(1)
    expect(QueryLog.inserts_into(statements, 'catalog_drugstore_brands')).to eq(1)
  end

  it 'counts every entry it saved' do
    saver.call(dictionaries)

    kinds = %i[forms measures price_groups temperature_modes restrictions brands]
    expect(tracker.run.reload.processed_count).to eq(kinds.sum { dictionaries.public_send(it).size })
  end

  it 'keeps the picture of a brand' do
    saver.call(dictionaries)
    brand = Catalog::Drugstore::Brand.first.tap { it.update!(image_path: 'brand.png') }

    described_class.new(Catalog::Sync::Linker.new(provider), tracker).call(dictionaries)

    expect(brand.reload.image_path).to eq('brand.png')
  end
end
