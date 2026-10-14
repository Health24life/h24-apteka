# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Pages::Resolve do
  let(:config) { Seo::Config.new(front_base_url: 'https://apteka.h24.ua', filter_params: %w[form]) }
  let(:goods) { create(:catalog_goods, slug: 'nurofen') }
  let(:category) { create(:catalog_category, slug: 'zneboliuvalni') }

  def resolve(path) = described_class.call(path, config:)

  def moved_to(path) = have_attributes(status: 301, location: path)

  describe 'the scheme of paths' do
    it 'recognises every kind of page', :aggregate_failures do
      expect(resolve('/').page.type).to eq(:home)
      expect(resolve('/cart').page.type).to eq(:cart)
      expect(resolve('/order/1024').page).to have_attributes(type: :order, order_number: '1024')
      expect(resolve("/katalog/#{category.slug}").page).to have_attributes(type: :category, record: category)
      expect(resolve("/tovar/#{goods.slug}").page).to have_attributes(type: :goods, record: goods)
    end

    it 'finds no page for a path outside the scheme', :aggregate_failures do
      expect(resolve('/apteky/kyiv').status).to eq(404)
      expect(resolve('/katalog').status).to eq(404)
      expect(resolve('/dobirka').status).to eq(404)
      expect(resolve('/tovar/nurofen/instruktsiia').status).to eq(404)
    end

    it 'finds no page for a slug no record has' do
      expect(resolve('/tovar/nema-takoho').status).to eq(404)
    end

    it 'answers the same for any order number, without looking it up' do
      expect(resolve('/order/999999999').status).to eq(200)
    end

    it 'keeps the case of an order number, which is part of it', :aggregate_failures do
      expect(resolve('/order/AB12CD34EF').page).to have_attributes(type: :order, order_number: 'AB12CD34EF')
      expect(resolve('/ORDER/AB12CD34EF/')).to moved_to('/order/AB12CD34EF')
    end

    it 'redirects the home page of a prefixed section from its trailing slash', :aggregate_failures do
      prefixed = Seo::Config.new(front_base_url: 'https://h24.ua/apteka')

      expect(described_class.call('/apteka/', config: prefixed)).to moved_to('/apteka')
      expect(described_class.call('/apteka/tovar/nema/', config: prefixed).status).to eq(404)
    end

    it 'recognises the paths under the section prefix only', :aggregate_failures do
      prefixed = Seo::Config.new(front_base_url: 'https://h24.ua/apteka')

      expect(described_class.call('/apteka/cart', config: prefixed).page.type).to eq(:cart)
      expect(described_class.call('/apteka', config: prefixed).page.type).to eq(:home)
      expect(described_class.call('/cart', config: prefixed).status).to eq(404)
    end
  end

  describe 'the normal form' do
    it 'redirects a trailing slash away' do
      expect(resolve("/tovar/#{goods.slug}/")).to moved_to('/tovar/nurofen')
    end

    it 'redirects capital letters to lower case' do
      expect(resolve("/Katalog/#{category.slug.capitalize}")).to moved_to('/katalog/zneboliuvalni')
    end

    it 'redirects the first page of a list to the list', :aggregate_failures do
      expect(resolve("/katalog/#{category.slug}?page=1")).to moved_to('/katalog/zneboliuvalni')
      expect(resolve("/katalog/#{category.slug}?page=abc")).to moved_to('/katalog/zneboliuvalni')
    end

    it 'keeps a later page of a list' do
      expect(resolve("/katalog/#{category.slug}?page=2").page.page_number).to eq(2)
    end

    it 'ignores UTM tags and other unknown parameters', :aggregate_failures do
      result = resolve("/tovar/#{goods.slug}?utm_source=fb&x=1")

      expect(result.status).to eq(200)
      expect(result.page).to eq(resolve("/tovar/#{goods.slug}").page)
    end

    it 'keeps the filters of the list and drops the rest from a redirect' do
      expect(resolve("/katalog/#{category.slug}/?form=tabletky&utm_source=fb&page=3"))
        .to moved_to('/katalog/zneboliuvalni?form=tabletky&page=3')
    end

    it 'treats a page of a product as an unknown parameter' do
      expect(resolve("/tovar/#{goods.slug}?page=1").status).to eq(200)
    end

    it 'redirects the home page with a trailing path to its normal form' do
      expect(resolve('/CART/')).to moved_to('/cart')
    end

    it 'ignores a parameter whose name or value is not valid text', :aggregate_failures do
      expect(resolve("/katalog/#{category.slug}?%E0%A4=1&q=%E0%A4%A").status).to eq(200)
      expect(resolve("/katalog/#{category.slug}?page=%E0%A4")).to moved_to('/katalog/zneboliuvalni')
    end
  end

  describe 'a changed slug' do
    it 'redirects every old slug straight to the current one', :aggregate_failures do
      goods.update!(slug: 'nurofen-forte')
      goods.update!(slug: 'nurofen-express')

      expect(resolve('/tovar/nurofen')).to moved_to('/tovar/nurofen-express')
      expect(resolve('/tovar/nurofen-forte')).to moved_to('/tovar/nurofen-express')
    end

    it 'redirects an old path in another form with one redirect' do
      goods.update!(slug: 'nurofen-forte')

      expect(resolve('/TOVAR/nurofen/')).to moved_to('/tovar/nurofen-forte')
    end

    it 'carries the page and the filters to the new slug of a category' do
      category.update!(slug: 'vid-boliu')

      expect(resolve('/katalog/zneboliuvalni?page=3&form=tabletky'))
        .to moved_to('/katalog/vid-boliu?form=tabletky&page=3')
    end

    it 'shows the page again on a slug the record took back' do
      goods.update!(slug: 'nurofen-forte')
      goods.update!(slug: 'nurofen')

      expect(resolve('/tovar/nurofen').status).to eq(200)
    end

    it 'stops redirecting once the period is over' do
      goods.update!(slug: 'nurofen-forte')
      Seo::Redirect.update_all(created_at: 4.months.ago) # rubocop:disable Rails/SkipsModelValidations
      Seo::Redirects::Cache.clear

      expect(resolve('/tovar/nurofen').status).to eq(404)
    end

    it 'still redirects when the cache lost the redirect' do
      goods.update!(slug: 'nurofen-forte')
      Seo::Redirects::Cache.clear

      expect(resolve('/tovar/nurofen')).to moved_to('/tovar/nurofen-forte')
    end

    it 'leads nowhere when the record of a redirect is gone' do
      goods.update!(slug: 'nurofen-forte')
      Seo::Redirects::Cache.redis.set(Seo::Redirects::Cache.key('goods', 'nurofen'), 'Catalog::Goods:0')

      expect(resolve('/tovar/nurofen').status).to eq(404)
    end

    it 'leads an old slug to a record of another kind' do
      create(:seo_redirect, page_type: 'goods', slug: 'staryi', redirectable: category)

      expect(resolve('/tovar/staryi')).to moved_to('/katalog/zneboliuvalni')
    end

    it 'does not take a slug of a goods for a category' do
      goods.update!(slug: 'nurofen-forte')

      expect(resolve('/katalog/nurofen').status).to eq(404)
    end
  end

  describe 'the state of a product page' do
    it 'is gone when the provider withdrew the SKU or its group', :aggregate_failures do
      expect(resolve("/tovar/#{create(:catalog_goods, withdrawn: true).slug}").status).to eq(410)

      group = create(:catalog_goods_group, withdrawn: true)
      expect(resolve("/tovar/#{create(:catalog_goods, goods_group: group).slug}").status).to eq(410)
    end

    it 'is not found when an operator hid the SKU or its group', :aggregate_failures do
      expect(resolve("/tovar/#{create(:catalog_goods, hidden: true).slug}").status).to eq(404)

      group = create(:catalog_goods_group, hidden: true)
      expect(resolve("/tovar/#{create(:catalog_goods, goods_group: group).slug}").status).to eq(404)
    end

    it 'is gone rather than not found when the SKU is both hidden and withdrawn' do
      expect(resolve("/tovar/#{create(:catalog_goods, hidden: true, withdrawn: true).slug}").status).to eq(410)
    end
  end

  describe 'a static page' do
    let(:page) { create(:seo_static_page, :published, name_uk: 'Умови сервісу') }

    it 'is found by its slug once it is published', :aggregate_failures do
      expect(resolve("/#{page.slug}"))
        .to have_attributes(status: 200, page: have_attributes(type: :static, record: page))
      expect(page.slug).to eq('umovy-servisu')
    end

    it 'is not found while it is not published' do
      expect(resolve("/#{create(:seo_static_page).slug}").status).to eq(404)
    end

    it 'is not found by a slug no page has' do
      expect(resolve('/nema-takoi').status).to eq(404)
    end

    it 'moves an address in another form to the normal one', :aggregate_failures do
      page

      expect(resolve('/Umovy-Servisu')).to moved_to('/umovy-servisu')
      expect(resolve('/umovy-servisu/')).to moved_to('/umovy-servisu')
    end

    it 'redirects its old slug to the current one' do
      page.update!(slug: 'umovy')

      expect(resolve('/umovy-servisu')).to moved_to('/umovy')
    end

    it 'ignores the parameters of a query' do
      expect(resolve("/#{page.slug}?page=2&utm_source=fb")).to have_attributes(status: 200, location: nil)
    end

    it 'gives the home page its row when there is one', :aggregate_failures do
      home = create(:seo_static_page, :home)

      expect(resolve('/').page).to have_attributes(type: :home, record: home)
    end
  end

  describe 'a filter page' do
    let(:filter) { create(:seo_filter, :published, name_uk: 'Вітаміни для дітей') }

    it 'is found by its slug once it is published' do
      expect(resolve("/dobirka/#{filter.slug}"))
        .to have_attributes(status: 200, page: have_attributes(type: :filter, record: filter))
    end

    it 'is not found while it is not published' do
      expect(resolve("/dobirka/#{create(:seo_filter).slug}")).to have_attributes(status: 404, location: nil)
    end

    it 'is not found by a slug no filter has' do
      expect(resolve('/dobirka/nema-takoi').status).to eq(404)
    end

    it 'is gone once the filter is removed' do
      filter.remove!

      expect(resolve("/dobirka/#{filter.slug}").status).to eq(410)
    end

    it 'redirects its old slug to the current one' do
      filter.update!(slug: 'vitaminy-ditiam')

      expect(resolve('/dobirka/vitaminy-dlia-ditei')).to moved_to('/dobirka/vitaminy-ditiam')
    end

    it 'moves an address in another form to the normal one and ignores the query', :aggregate_failures do
      filter

      expect(resolve('/Dobirka/Vitaminy-Dlia-Ditei/')).to moved_to('/dobirka/vitaminy-dlia-ditei')
      expect(resolve('/dobirka/vitaminy-dlia-ditei?form=tabletky&page=2'))
        .to have_attributes(status: 200, location: nil, page: have_attributes(filters: {}, page_number: nil))
    end
  end

  describe 'a redirect an editor set' do
    def redirect(page_type, slug, to) = create(:seo_redirect, manual: true, page_type:, slug:, redirectable: to)

    it 'leads a withdrawn product to a category' do
      redirect('goods', create(:catalog_goods, withdrawn: true, slug: 'nurofen-stare').slug, category)

      expect(resolve('/tovar/nurofen-stare')).to moved_to('/katalog/zneboliuvalni')
    end

    it 'leads a hidden product away as well' do
      redirect('goods', create(:catalog_goods, hidden: true, slug: 'pryhovanyi').slug, category)

      expect(resolve('/tovar/pryhovanyi')).to moved_to('/katalog/zneboliuvalni')
    end

    it 'follows the slug its target has now' do
      redirect('goods', 'staryi', goods)
      goods.update!(slug: 'nurofen-forte')

      expect(resolve('/tovar/staryi')).to moved_to('/tovar/nurofen-forte')
    end

    it 'gives way to the product once it is shown again' do
      withdrawn = create(:catalog_goods, withdrawn: true, slug: 'nurofen-stare')
      redirect('goods', withdrawn.slug, category)
      withdrawn.update!(withdrawn: false)

      expect(resolve('/tovar/nurofen-stare').status).to eq(200)
    end

    it 'stops leading to a target that left the storefront' do
      redirect('goods', 'staryi', create(:catalog_goods, withdrawn: true))

      expect(resolve('/tovar/staryi').status).to eq(404)
    end

    it 'leads to the home page' do
      redirect('category', 'akcii', create(:seo_static_page, :home))

      expect(resolve('/katalog/akcii')).to moved_to('/')
    end

    it 'leads from the slug of a removed static page' do
      create(:seo_static_page, :published, slug: 'akcii').destroy!
      redirect('static', 'akcii', category)

      expect(resolve('/akcii')).to moved_to('/katalog/zneboliuvalni')
    end

    it 'carries the page and the filters only from a category to a category', :aggregate_failures do
      redirect('category', 'stara', category)
      redirect('category', 'tovarna', goods)

      expect(resolve('/katalog/stara?page=2&form=tabletky')).to moved_to('/katalog/zneboliuvalni?form=tabletky&page=2')
      expect(resolve('/katalog/tovarna?page=2')).to moved_to('/tovar/nurofen')
    end

    it 'leads from the slug of a removed filter' do
      create(:seo_filter, :published, slug: 'dlia-skhudnennia').remove!
      redirect('filter', 'dlia-skhudnennia', category)

      expect(resolve('/dobirka/dlia-skhudnennia')).to moved_to('/katalog/zneboliuvalni')
    end

    it 'stops leading to a filter that is no longer published' do
      filter = create(:seo_filter, :published)
      redirect('goods', 'staryi', filter)
      filter.update!(published: false)

      expect(resolve('/tovar/staryi').status).to eq(404)
    end

    it 'leaves an automatic redirect leading to its record wherever that is' do
      goods.update!(slug: 'nurofen-forte')
      goods.update!(withdrawn: true)

      expect(resolve('/tovar/nurofen')).to moved_to('/tovar/nurofen-forte')
    end
  end

  it 'tells what a page that is not there would be', :aggregate_failures do
    expect(resolve('/tovar/nema-takoho').page).to have_attributes(type: :goods, record: nil)
    expect(resolve("/tovar/#{create(:catalog_goods, withdrawn: true).slug}").page.type).to eq(:goods)
  end
end
