# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::GoodsGroups do
  let(:body) { JSON.parse(pharmapoint_fixture('goods_group_search')) }
  let(:page) { described_class.page(body, page: 1, per_page: 2) }
  let(:group) { page.items.first }
  let(:goods) { group[:goods].first }

  it 'reads the page with the total of items and the last page' do
    expect(page).to have_attributes(page: 1, per_page: 2, total: 5, last_page: 3)
  end

  it 'reads the group with its producer, trade name and categories' do
    expect(group).to include(
      external_id: 'a060d7776d3d256af22378e018bea336', name: 'Спазмалгон табл. №50(10х5)',
      producer: { external_id: '48424', name: 'Balkanpharma', country: 'Болгария', country_code: 'BG' },
      goods_name: { external_id: '3264', name: 'Спазмалгон' }
    )
  end

  it 'reads the ATC class with its ancestors from the root down' do
    expect(group[:atc_class]).to include(
      external_id: '7937', atc_code: 'N02B A51',
      ancestors: [ { external_id: '7234', atc_code: 'N02', name: 'Анальгетики' },
                   { external_id: '7454', atc_code: 'N02B', name: 'Другие анальгетики и антипиретики' } ]
    )
  end

  it 'reads the category with the path from the root to it' do
    expect(group[:categories].first[:path].pluck(:external_id)).to eq(%w[950 960 970 980])
  end

  it 'reads the static card of a release form and keeps the partner barcode as the Morion code' do
    expect(goods).to include(external_id: '1795034', morion_code: '470684', release_form: 'табл.', dosage: '500mg',
                             mnn: 'Pitofenone and analgesics')
  end

  it 'reads the image paths of a release form' do
    expect(goods[:image_paths]).to eq([ 'goods_profile_photo/1795034/J8Fqd8dtKgZrde3L.jpg' ])
  end

  it 'reads the packing of a release form' do
    expect(goods[:pack]).to eq(unit_name: 'plate', quantity_in_pack: 50, quantity_unit_in_pack: 5, quantity_in_unit: 10)
  end

  it 'reads the references to dictionaries as ids of the partner', :aggregate_failures do
    expect(goods).to include(form: '223', measure: '1', price_group: '2', temperature_mode: '3',
                             adult_restriction: '1', child_restriction: '3', driver_restriction: nil)
  end

  it 'never reads price, stock, VAT, pre-order or drugstore counts', :aggregate_failures do
    keys = [ group, goods ].flat_map(&:keys).map(&:to_s)

    expect(keys).to all(satisfy { |key| key.exclude?('price') || key == 'price_group' })
    expect(keys & %w[quantity nds preorder drugstores_count_available online_price]).to be_empty
    expect(goods.to_s).not_to include('277.51')
  end

  it 'takes a missing key, null and an empty array in place of an object for no value', :aggregate_failures do
    second_goods = page.items.first[:goods].second
    other_group = page.items.second

    expect(second_goods).to include(instruction_html: nil, form: nil, image_paths: [], composition: nil)
    expect(other_group).to include(goods_name: nil, atc_class: nil, categories: [])
    expect(other_group[:producer]).to include(external_id: '5001', country: nil, country_code: nil)
  end

  it 'turns an empty instruction into no instruction' do
    expect(page.items.second[:goods].first[:instruction_html]).to be_nil
  end

  it 'reads a single group from the by-id answer' do
    one = described_class.one(JSON.parse(pharmapoint_fixture('goods_group_get_by_id')))

    expect(one[:external_id]).to eq('a060d7776d3d256af22378e018bea336')
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
