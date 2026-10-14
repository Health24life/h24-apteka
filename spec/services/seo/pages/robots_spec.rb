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

  describe 'an override of the page' do
    it 'keeps a product out of the index when an operator says so' do
      goods = create(:seo_override, robots: 'noindex').target

      expect(described_class.call(page(:goods, record: goods))).to eq('noindex, follow')
    end

    it 'indexes a category with nothing to show when an operator says so' do
      create(:seo_override, target: category, robots: 'index')

      expect(described_class.call(page(:category, record: category))).to eq('index, follow')
    end

    it 'keeps a filtered list out of the index whatever its category says' do
      create(:seo_override, target: category, robots: 'index')

      expect(described_class.call(page(:category, record: category, filters: { 'form' => 'tabletky' })))
        .to eq('noindex, follow')
    end
  end

  it 'indexes a static page unless an operator closed it', :aggregate_failures do
    static_page = create(:seo_static_page, :published)
    expect(described_class.call(page(:static, record: static_page))).to eq('index, follow')

    create(:seo_override, target: static_page, robots: 'noindex')
    expect(described_class.call(page(:static, record: static_page.reload))).to eq('noindex, follow')
  end

  describe 'a filter' do
    let(:filter) { create(:seo_filter, :stocked) }

    it 'is indexed once published with goods to show' do
      expect(described_class.call(page(:filter, record: filter))).to eq('index, follow')
    end

    it 'only leads on when nothing on the storefront matches it' do
      expect(described_class.call(page(:filter, record: create(:seo_filter, :published)))).to eq('noindex, follow')
    end

    it 'is indexed without goods when an operator says so' do
      empty = create(:seo_filter, :published)
      create(:seo_override, target: empty, robots: 'index')

      expect(described_class.call(page(:filter, record: empty))).to eq('index, follow')
    end

    it 'is kept out of the index when an operator says so' do
      create(:seo_override, target: filter, robots: 'noindex')

      expect(described_class.call(page(:filter, record: filter))).to eq('noindex, follow')
    end
  end
end
