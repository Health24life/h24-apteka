# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Redirects::Manual do
  let(:config) { Seo::Config.new(front_base_url: 'https://apteka.h24.ua') }
  let!(:category) { create(:catalog_category, slug: 'zneboliuvalni') }

  def manual(source, target, **) = described_class.call(source:, target:, config:, **)

  it 'leads a withdrawn product to a category', :aggregate_failures do
    create(:catalog_goods, slug: 'nurofen-stare', withdrawn: true)

    expect(manual('https://apteka.h24.ua/tovar/nurofen-stare/', '/katalog/zneboliuvalni').redirect)
      .to have_attributes(manual: true, page_type: 'goods', slug: 'nurofen-stare', redirectable: category)
    expect(Seo::Pages::Resolve.call('/tovar/nurofen-stare', config:).location).to eq('/katalog/zneboliuvalni')
  end

  it 'only checks without saving when asked', :aggregate_failures do
    expect(manual('/tovar/nema', '/katalog/zneboliuvalni', save: false)).to be_ok
    expect(Seo::Redirect.count).to eq(0)
  end

  it 'refuses an old address that has a page', :aggregate_failures do
    create(:catalog_goods, slug: 'nurofen')

    expect(manual('/tovar/nurofen', '/katalog/zneboliuvalni').errors).to eq(source: :page_there)
    expect(Seo::Redirect.count).to eq(0)
  end

  it 'refuses an old address something already leads from' do
    create(:catalog_goods, slug: 'nurofen').update!(slug: 'nurofen-forte')

    expect(manual('/tovar/nurofen', '/katalog/zneboliuvalni').errors).to eq(source: :redirected)
  end

  it 'refuses an old address that is not a product, a category or a static page', :aggregate_failures do
    expect(manual('/apteky/kyiv/centr', '/katalog/zneboliuvalni').errors).to eq(source: :not_a_page)
    expect(manual('/cart', '/katalog/zneboliuvalni').errors).to eq(source: :not_a_page)
  end

  it 'refuses an address outside the section' do
    expect(manual('/tovar/nema', 'https://h24.ua/doctors').errors).to eq(target: :other_host)
  end

  it 'refuses a target that is not on the storefront', :aggregate_failures do
    hidden = create(:catalog_goods, hidden: true)

    expect(manual('/tovar/nema', "/tovar/#{hidden.slug}").errors).to eq(target: :unavailable)
    expect(manual('/tovar/nema', '/cart').errors).to eq(target: :not_a_page)
  end

  it 'leads to the page where an address that redirects ends' do
    medicines = create(:catalog_category, slug: 'liky')
    medicines.update!(slug: 'likarski-zasoby')

    expect(manual('/tovar/nema', '/katalog/liky').redirect.redirectable).to eq(medicines)
  end

  it 'leads to the home page and from the address of a removed static page' do
    create(:seo_static_page, :published, slug: 'akcii').destroy!
    home = create(:seo_static_page, :home)

    expect(manual('/akcii', '/').redirect).to have_attributes(page_type: 'static', slug: 'akcii', redirectable: home)
  end

  it 'leads from the address of a removed filter to a category', :aggregate_failures do
    create(:seo_filter, :published, slug: 'dlia-skhudnennia').remove!

    expect(manual('/dobirka/dlia-skhudnennia', '/katalog/zneboliuvalni').redirect)
      .to have_attributes(page_type: 'filter', slug: 'dlia-skhudnennia', redirectable: category)
    expect(Seo::Pages::Resolve.call('/dobirka/dlia-skhudnennia', config:).location).to eq('/katalog/zneboliuvalni')
  end

  it 'leads to a published filter but not to one that is not', :aggregate_failures do
    published = create(:seo_filter, :published, slug: 'vitaminy-dlia-ditei')
    create(:seo_filter, slug: 'dlia-imunitetu')

    expect(manual('/tovar/nema', '/dobirka/vitaminy-dlia-ditei').redirect.redirectable).to eq(published)
    expect(manual('/tovar/nema-2', '/dobirka/dlia-imunitetu').errors).to eq(target: :unavailable)
  end

  it 'leads a redirect to another page and keeps its period', :aggregate_failures do
    redirect = manual('/tovar/nema', '/katalog/zneboliuvalni').redirect
    other = create(:catalog_category, slug: 'inshi')

    described_class.call(source: nil, target: '/katalog/inshi', redirect:, config:)

    expect(redirect.reload).to have_attributes(redirectable: other, slug: 'nema')
    expect(Seo::Pages::Resolve.call('/tovar/nema', config:).location).to eq('/katalog/inshi')
  end

  it 'lets only one of two editors set a redirect from the same address' do
    first = manual('/tovar/nema', '/katalog/zneboliuvalni', save: false).redirect
    manual('/tovar/nema', '/katalog/zneboliuvalni')

    expect(described_class.new(config).send(:store, first).errors).to eq(source: :redirected)
  end

  describe '.target_error' do
    def target_error(target) = described_class.target_error(target, config:)

    it 'accepts a page on the storefront without an old address' do
      expect(target_error('/katalog/zneboliuvalni')).to be_nil
    end

    it 'names why a target is refused', :aggregate_failures do
      hidden = create(:catalog_goods, hidden: true)

      expect(target_error("/tovar/#{hidden.slug}")).to eq(:unavailable)
      expect(target_error('https://h24.ua/doctors')).to eq(:other_host)
      expect(target_error('/cart')).to eq(:not_a_page)
    end
  end
end
