# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Pages::Breadcrumbs do
  let(:medicines) { create(:catalog_category, name_uk: 'Ліки', slug: 'liky') }
  let(:painkillers) { create(:catalog_category, name_uk: 'Знеболювальні', slug: 'zneboliuvalni', parent: medicines) }
  let(:group) { create(:catalog_goods_group) }
  let(:goods) { create(:catalog_goods, name_uk: 'Нурофен', slug: 'nurofen', goods_group: group) }

  def page(type, record: nil, order_number: nil)
    Seo::Pages::Resolve::Page.new(type:, record:, order_number:, page_number: nil, filters: {})
  end

  def trail(page) = described_class.call(page).map(&:to_h)

  it 'leads a product through the main category of its group and that category\'s ancestors' do
    create(:catalog_goods_group_category, goods_group: group, category: painkillers, is_primary: true)

    expect(trail(page(:goods, record: goods))).to eq(
      [ { name: 'Головна', path: '/' }, { name: 'Ліки', path: '/katalog/liky' },
        { name: 'Знеболювальні', path: '/katalog/zneboliuvalni' }, { name: 'Нурофен', path: '/tovar/nurofen' } ]
    )
  end

  it 'leads a product of a group without a main category straight from the home page' do
    create(:catalog_goods_group_category, goods_group: group, category: painkillers)

    expect(trail(page(:goods, record: goods)).pluck(:name)).to eq(%w[Головна Нурофен])
  end

  it 'leads a category through its ancestors' do
    expect(trail(page(:category, record: painkillers)).pluck(:name)).to eq(%w[Головна Ліки Знеболювальні])
  end

  it 'uses the current slug of an ancestor' do
    medicines.update!(slug: 'likarski-zasoby')

    expect(trail(page(:category, record: painkillers)).second).to eq(name: 'Ліки', path: '/katalog/likarski-zasoby')
  end

  it 'gives the home page, the cart and an order their own trail', :aggregate_failures do
    expect(trail(page(:home))).to eq([ { name: 'Головна', path: '/' } ])
    expect(trail(page(:cart)).last).to eq(name: 'Кошик', path: '/cart')
    expect(trail(page(:order, order_number: '1024')).last).to eq(name: 'Замовлення', path: '/order/1024')
  end
end
