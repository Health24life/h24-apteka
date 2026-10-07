# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::GoodsGroups do
  let(:body) { JSON.parse(pharmapoint_fixture('goods_group_search')) }
  let(:page) { described_class.page(body, page: 1, per_page: 2) }
  let(:group) { page.items.first }
  let(:goods) { group.goods.first }

  it 'reads the page with the total of items and the last page' do
    expect(page).to have_attributes(page: 1, per_page: 2, total: 5, last_page: 3)
  end

  it 'reads the group with its name and the id of the partner' do
    expect(group).to have_attributes(external_id: 'a060d7776d3d256af22378e018bea336',
                                     name: 'Спазмалгон табл. №50(10х5)', included_to_offers: false)
  end

  it 'reads the producer with the country code in capitals' do
    expect(group.producer).to eq(Pharmapoint::Producer.new(external_id: '48424', name: 'Balkanpharma',
                                                           country: 'Болгария', country_code: 'BG'))
  end

  it 'reads the trade name' do
    expect(group.goods_name).to eq(Pharmapoint::GoodsName.new(external_id: '3264', name: 'Спазмалгон'))
  end

  it 'reads the ATC class with its ancestors from the root down', :aggregate_failures do
    expect(group.atc_class).to have_attributes(external_id: '7937', atc_code: 'N02B A51')
    expect(group.atc_class.ancestors.map(&:atc_code)).to eq(%w[N02 N02B])
  end

  it 'reads the category with the path from the root to it', :aggregate_failures do
    category = group.categories.sole

    expect(category).to have_attributes(external_id: '980', name: 'Інші анальгетики й антипіретики')
    expect(category.path.map(&:external_id)).to eq(%w[950 960 970 980])
  end

  it 'reads the static card of a release form and keeps the partner barcode as the Morion code', :aggregate_failures do
    expect(goods).to have_attributes(external_id: '1795034', morion_code: '470684')
    expect(goods.card).to have_attributes(release_form: 'табл.', dosage: '500mg', mnn: 'Pitofenone and analgesics')
  end

  it 'reads the image paths of a release form' do
    expect(goods.card.image_paths).to eq([ 'goods_profile_photo/1795034/J8Fqd8dtKgZrde3L.jpg' ])
  end

  it 'reads the packing of a release form' do
    expect(goods.pack).to eq(Pharmapoint::Pack.new(unit_name: 'plate', quantity_in_pack: 50, quantity_unit_in_pack: 5,
                                                   quantity_in_unit: 10))
  end

  it 'reads the references to dictionaries as ids of the partner', :aggregate_failures do
    expect(goods.references).to have_attributes(form: '223', measure: '1', price_group: '2', temperature_mode: '3',
                                                adult_restriction: '1', child_restriction: '3')
    expect(goods.references.driver_restriction).to be_nil
  end

  it 'has no place for price, stock, VAT, pre-order or drugstore counts', :aggregate_failures do
    members = [ Pharmapoint::GoodsGroup, Pharmapoint::Goods, Pharmapoint::GoodsCard ].flat_map(&:members)

    expect(members & %i[online_price drugstore_price quantity nds preorder drugstores_count_available]).to be_empty
    expect(group.as_json.to_s).not_to include('277.51')
  end

  it 'takes a missing key, null and an empty array in place of an object for no value', :aggregate_failures do
    bare = group.goods.second

    expect(bare.card).to have_attributes(instruction_html: nil, composition: nil, image_paths: [])
    expect(bare.references.form).to be_nil
  end

  it 'reads a group with no trade name, class or category as a group without them', :aggregate_failures do
    other = page.items.second

    expect(other).to have_attributes(goods_name: nil, atc_class: nil, categories: [])
    expect(other.producer).to have_attributes(external_id: '5001', country: nil, country_code: nil)
  end

  it 'turns an empty instruction into no instruction' do
    expect(page.items.second.goods.first.card.instruction_html).to be_nil
  end

  it 'reads a single group from the by-id answer' do
    one = described_class.one(JSON.parse(pharmapoint_fixture('goods_group_get_by_id')))

    expect(one.external_id).to eq('a060d7776d3d256af22378e018bea336')
  end

  it 'refuses an answer that is not an object or has no data', :aggregate_failures do
    expect { described_class.page([], page: 1, per_page: 2) }.to raise_error(Pharmapoint::InvalidResponse)
    expect { described_class.page({ 'meta' => {} }, page: 1, per_page: 2) }.to raise_error(Pharmapoint::InvalidResponse)
  end

  it 'counts the items as the total when the answer has no meta' do
    result = described_class.page({ 'data' => body['data'] }, page: 1, per_page: 50)

    expect(result).to have_attributes(total: 2, last_page: 1)
  end
end
