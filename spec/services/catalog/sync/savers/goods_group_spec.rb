# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Savers::GoodsGroup do
  subject(:saver) { described_class.new(linker, tracker) }

  let(:provider) { create(:provider) }
  let(:linker) { Catalog::Sync::Linker.new(provider) }
  let(:tracker) { Catalog::Sync::RunTracker.start(provider:, kind: 'goods_groups') }
  let(:item) { Pharmapoint::Readers::GoodsGroups.page(JSON.parse(pharmapoint_fixture('goods_group_search')), page: 1, per_page: 2).items.first }

  before do
    {
      Catalog::Goods::Form => '223', Catalog::Goods::Measure => '1', Catalog::Goods::PriceGroup => '2',
      Catalog::Goods::TemperatureMode => '3'
    }.each { |model, id| linker.sync(model, id, name_uk: 'x') }
    %w[1 3].each { linker.sync(Catalog::Goods::Restriction, it, name_uk: 'x') }
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
    existing = linker.sync(Catalog::Category, '980', name_uk: 'Раніше')

    group = saver.call(item)

    expect(group.categories).to eq([ existing ])
    expect(Provider::Link.where(linkable_type: 'Catalog::Category', external_id: '980').count).to eq(1)
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
    unnamed = item.with(producer: Pharmapoint::Producer.new(external_id: '1', name: nil, country: nil,
                                                            country_code: nil))

    expect { saver.call(unnamed) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Catalog::Goods::Group.count).to eq(0)
  end

  describe 'when a SKU names a dictionary entry that is not there' do
    let(:broken) do
      missing_form = item.goods.first.references.with(form: '999')
      item.with(goods: [ item.goods.first.with(references: missing_form), *item.goods.drop(1) ])
    end

    before { saver.call(broken) }

    it 'logs that SKU' do
      expect(tracker.run.failures.sole).to have_attributes(error_class: 'Catalog::Sync::MissingReference',
                                                           external_id: '1795034')
    end

    it 'saves the other SKU' do
      expect(Catalog::Goods.pluck(:morion_code)).to eq([ '470685' ])
    end
  end

  it 'stores the Ukrainian name, or the main name when there is none' do
    renamed = item.with(goods: [ item.goods.first.with(name: 'Основна назва'), *item.goods.drop(1) ])

    group = saver.call(renamed)

    expect(group.goods.find_by(morion_code: '470684').name_uk).to eq('Основна назва')
  end

  def group_without_optionals
    page = Pharmapoint::Readers::GoodsGroups.page(JSON.parse(pharmapoint_fixture('goods_group_search')), page: 1,
                                                                                                         per_page: 2)
    page.items.last
  end
end
