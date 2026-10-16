# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Search::LocalGoods do
  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:group) { create(:catalog_goods_group) }

  def hit(external_id, group_external_id: 'group-1')
    Catalog::Search::Hit.new(
      provider: provider.code,
      group_external_id:,
      external_id:,
      name: 'Спазмалгон',
      release_form: nil,
      dosage: nil,
      pack: {},
      trade_name: nil,
      producer_name: nil,
      producer_country_code: nil,
      group_name: nil,
      is_recipe: false,
      is_strict_recipe: false,
      ready: false,
      id: nil,
      slug: nil
    )
  end

  def link(record, external_id, on: provider)
    Provider::Link.create!(provider: on, linkable: record, external_id:, synced_at: Time.current)
    record
  end

  def call(*hits) = described_class.call(provider, hits)

  it 'leads a SKU the catalog shows to its card' do
    goods = link(create(:catalog_goods, goods_group: group), 'sku-1')

    expect(call(hit('sku-1')).sole).to have_attributes(ready: true, id: goods.id, slug: goods.slug)
  end

  it 'lists a SKU the catalog lacks as not ready, with no id or address' do
    expect(call(hit('sku-1')).sole).to have_attributes(ready: false, id: nil, slug: nil)
  end

  it 'does not take a SKU of another provider for its own' do
    link(create(:catalog_goods, goods_group: group), 'sku-1', on: create(:provider))

    expect(call(hit('sku-1')).sole.ready).to be(false)
  end

  it 'leaves out a SKU an operator hid' do
    link(create(:catalog_goods, goods_group: group, hidden: true), 'sku-1')

    expect(call(hit('sku-1'), hit('sku-2'))).to contain_exactly(have_attributes(external_id: 'sku-2'))
  end

  it 'leaves out every SKU of a hidden group, saved or not' do
    group.update!(hidden: true)
    link(group, 'group-1')
    link(create(:catalog_goods, goods_group: group), 'sku-1')

    expect(call(hit('sku-1'), hit('sku-2'), hit('sku-3', group_external_id: 'group-2')).map(&:external_id))
      .to eq(%w[sku-3])
  end

  it 'lists a withdrawn SKU, or a SKU of a withdrawn group, as not ready', :aggregate_failures do
    link(create(:catalog_goods, goods_group: group, withdrawn: true), 'sku-1')
    withdrawn_group = create(:catalog_goods_group, withdrawn: true)
    link(create(:catalog_goods, goods_group: withdrawn_group), 'sku-2')

    expect(call(hit('sku-1'), hit('sku-2')).map(&:ready)).to eq([ false, false ])
  end

  it 'keeps the order of the provider' do
    link(create(:catalog_goods, goods_group: group), 'sku-2')

    expect(call(hit('sku-3'), hit('sku-2'), hit('sku-1')).map(&:external_id)).to eq(%w[sku-3 sku-2 sku-1])
  end

  it 'checks a page in one query' do
    hits = [ hit('sku-1'), hit('sku-2') ]

    expect(QueryLog.capture { described_class.call(provider, hits) }.size).to eq(1)
  end
end
