# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::StashableGoodsGroup do
  let(:record) { complete_goods_group }

  def stashed = described_class.call(record)

  it 'keeps the static card of the group and of every SKU', :aggregate_failures do
    expect(stashed).to include(
      'id' => 'a060d7776d3d256af22378e018bea336',
      'goods_categories' => record['goods_categories']
    )
    expect(stashed['release_forms'].pluck('id')).to eq(record['release_forms'].pluck('id'))
  end

  it 'drops the live fields of the group and of every SKU', :aggregate_failures do
    expect(stashed.keys & described_class::LIVE_KEYS).to be_empty
    expect(stashed['release_forms'].flat_map(&:keys) & described_class::LIVE_KEYS).to be_empty
  end

  it 'can be read back into the same group' do
    reader = Pharmapoint::Readers::GoodsGroups

    expect(reader.one('data' => stashed)).to eq(reader.one('data' => record))
  end

  it 'leaves out a group with a SKU that has no instruction' do
    record['release_forms'].last['instruction'] = nil

    expect(stashed).to be_nil
  end

  it 'leaves out a group without SKU' do
    record['release_forms'] = []

    expect(stashed).to be_nil
  end

  it 'leaves out a group without categories' do
    record['goods_categories'] = []

    expect(stashed).to be_nil
  end
end
