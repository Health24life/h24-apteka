# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Pages::Robots do
  let(:category) { create(:catalog_category) }

  def page(type, record: nil, filters: {})
    Seo::Pages::Resolve::Page.new(type:, record:, order_number: nil, page_number: nil, filters:)
  end

  def stock(category)
    group = create(:catalog_goods_group)
    create(:catalog_goods_group_category, goods_group: group, category:)
    create(:catalog_goods, goods_group: group)
  end

  it 'keeps the cart and the order out of search entirely', :aggregate_failures do
    expect(described_class.call(page(:cart))).to eq('noindex, nofollow')
    expect(described_class.call(page(:order))).to eq('noindex, nofollow')
  end

  it 'indexes the home page and a product', :aggregate_failures do
    expect(described_class.call(page(:home))).to eq('index, follow')
    expect(described_class.call(page(:goods, record: create(:catalog_goods)))).to eq('index, follow')
  end

  it 'indexes a category with something to show' do
    stock(category)

    expect(described_class.call(page(:category, record: category))).to eq('index, follow')
  end

  it 'only follows a filtered list' do
    stock(category)

    expect(described_class.call(page(:category, record: category, filters: { 'form' => 'tabletky' })))
      .to eq('noindex, follow')
  end

  it 'only follows a category with nothing to show' do
    expect(described_class.call(page(:category, record: category))).to eq('noindex, follow')
  end
end
