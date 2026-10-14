# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Pages::Path do
  subject(:paths) { described_class.new(Seo::Config.new(front_base_url:)) }

  let(:front_base_url) { 'https://apteka.h24.ua' }

  it 'builds the path of every page of the scheme', :aggregate_failures do
    expect(paths.home).to eq('/')
    expect(paths.cart).to eq('/cart')
    expect(paths.order('A-17')).to eq('/order/A-17')
    expect(paths.record(build(:catalog_category, slug: 'zneboliuvalni'))).to eq('/katalog/zneboliuvalni')
    expect(paths.record(build(:catalog_goods, slug: 'nurofen'))).to eq('/tovar/nurofen')
  end

  it 'builds the path of a filter' do
    expect(paths.record(build(:seo_filter, slug: 'vitaminy-dlia-ditei'))).to eq('/dobirka/vitaminy-dlia-ditei')
  end

  it 'adds the query in the given order' do
    expect(paths.with_query('/katalog/liky', { 'page' => '2', 'form' => 'tabletky' }))
      .to eq('/katalog/liky?page=2&form=tabletky')
  end

  it 'gives the full URL of a path on the front host' do
    expect(paths.url('/tovar/nurofen')).to eq('https://apteka.h24.ua/tovar/nurofen')
  end

  context 'when the section lives under a path of the front host' do
    let(:front_base_url) { 'https://h24.ua/apteka' }

    it 'puts the prefix in front of every path', :aggregate_failures do
      expect(paths.home).to eq('/apteka')
      expect(paths.cart).to eq('/apteka/cart')
      expect(paths.url(paths.cart)).to eq('https://h24.ua/apteka/cart')
    end
  end
end
