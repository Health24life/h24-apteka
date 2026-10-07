# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::GoodsGroupSaver do
  subject(:saver) { described_class.new(linker, tracker) }

  let(:provider) { create(:provider) }
  let(:linker) { Catalog::Sync::Linker.new(provider) }
  let(:tracker) { Catalog::Sync::RunTracker.start(provider:, kind: 'goods_groups') }
  let(:item) { Pharmapoint::Readers::GoodsGroups.page(JSON.parse(pharmapoint_fixture('goods_group_search')), page: 1, per_page: 2).items.first }

  before do
    {
      Catalog::GoodsForm => '223', Catalog::GoodsMeasure => '1', Catalog::GoodsPriceGroup => '2',
      Catalog::GoodsTemperatureMode => '3'
    }.each { |model, id| linker.sync(model, id, name_uk: 'x') }
    %w[1 3].each { linker.sync(Catalog::GoodsRestriction, it, name_uk: 'x') }
  end

  it 'creates the producer with the country code in capitals' do
    group = saver.call(item)

    expect(group.producer).to have_attributes(name: 'Balkanpharma', country: 'Болгария', country_code: 'BG')
  end

  it 'chains the ATC class under its ancestors, root down', :aggregate_failures do
    group = saver.call(item)

    expect(group.atc_class).to have_attributes(atc_code: 'N02B A51', parent: have_attributes(atc_code: 'N02B'))
    expect(group.atc_class.parent.parent).to have_attributes(atc_code: 'N02', parent: nil)
  end

  it 'builds a category the tree import has not brought from the path the group carries', :aggregate_failures do
    group = saver.call(item)

    leaf = group.categories.sole
    expect(leaf).to have_attributes(depth: 3, name_uk: 'Інші анальгетики й антипіретики')
    expect(leaf.parent.parent.parent).to have_attributes(name_uk: 'Ліки', parent: nil)
  end

  it 'uses a category that is already there instead of building another', :aggregate_failures do
    existing = linker.sync(Catalog::Category, '980', name_uk: 'Раніше') { Catalog::CategorySaver.call(it) }

    group = saver.call(item)

    expect(group.categories).to eq([ existing ])
    expect(ProviderLink.where(linkable_type: 'Catalog::Category', external_id: '980').count).to eq(1)
  end

  it 'makes the first category of the list the primary one and drops those that left the list', :aggregate_failures do
    group = saver.call(item)
    stale = create(:catalog_category)
    group.goods_group_categories.create!(category: stale)

    saver.call(item)

    expect(group.reload.goods_group_categories.sole).to have_attributes(is_primary: true)
  end

  it 'stores the SKU without a barcode column and with the Morion code', :aggregate_failures do
    group = saver.call(item)

    expect(group.goods.pluck(:morion_code)).to contain_exactly('470684', '470685')
    expect(Catalog::Goods.column_names).not_to include('barcode')
  end

  it 'saves a SKU without the optional fields', :aggregate_failures do
    bare = group_without_optionals

    group = saver.call(bare)

    expect(group.goods.sole).to have_attributes(measure: nil, mnn: nil, composition: nil, pack_quantity_unit_in_pack: 1)
    expect(group).to have_attributes(goods_name: nil, atc_class: nil, producer: have_attributes(country: nil))
  end

  it 'refuses a group whose producer has no name and saves nothing of it', :aggregate_failures do
    item[:producer] = { external_id: '1', name: nil, country: nil, country_code: nil }

    expect { saver.call(item) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Catalog::GoodsGroup.count).to eq(0)
  end

  it 'logs a SKU that names a dictionary entry which is not there, and saves the others', :aggregate_failures do
    item[:goods].first[:form] = '999'

    saver.call(item)

    expect(tracker.run.failures.sole).to have_attributes(error_class: 'Catalog::Sync::MissingReference',
                                                         external_id: '1795034')
    expect(Catalog::Goods.pluck(:morion_code)).to eq([ '470685' ])
  end

  it 'stores the Ukrainian name, or the main name when there is none' do
    item[:goods].first[:name] = 'Основна назва'

    group = saver.call(item)

    expect(group.goods.find_by(morion_code: '470684').name_uk).to eq('Основна назва')
  end

  def group_without_optionals
    page = Pharmapoint::Readers::GoodsGroups.page(JSON.parse(pharmapoint_fixture('goods_group_search')), page: 1,
                                                                                                         per_page: 2)
    page.items.last
  end
end
