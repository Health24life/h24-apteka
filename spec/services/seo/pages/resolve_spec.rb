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
      expect(resolve('/tovar/nurofen/instruktsiia').status).to eq(404)
    end

    it 'finds no page for a slug no record has' do
      expect(resolve('/tovar/nema-takoho').status).to eq(404)
    end

    it 'answers the same for any order number, without looking it up' do
      expect(resolve('/order/999999999').status).to eq(200)
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

    it 'stops redirecting once the cache no longer holds the redirect' do
      goods.update!(slug: 'nurofen-forte')
      Seo::Redirects::Cache.clear

      expect(resolve('/tovar/nurofen').status).to eq(404)
    end

    it 'leads nowhere when the record of a redirect is gone' do
      goods.update!(slug: 'nurofen-forte')
      Seo::Redirects::Cache.redis.set(Seo::Redirects::Cache.key('Catalog::Goods', 'nurofen'), 0)

      expect(resolve('/tovar/nurofen').status).to eq(404)
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
end
