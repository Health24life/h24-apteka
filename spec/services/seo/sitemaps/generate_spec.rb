# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Sitemaps::Generate do
  include ActiveSupport::Testing::TimeHelpers

  let(:dir) { Dir.mktmpdir }
  let(:config) { Seo::Config.new(front_base_url: 'https://apteka.h24.ua', sitemap_dir: dir) }
  let(:category) { create(:catalog_category, slug: 'zneboliuvalni') }

  after { FileUtils.rm_rf(dir) }

  def generate = described_class.call(config:)

  def served(name) = File.read(File.join(dir, 'current', name))

  def stocked(slug, category: self.category, **goods)
    group = create(:catalog_goods_group)
    create(:catalog_goods_group_category, goods_group: group, category:)
    create(:catalog_goods, goods_group: group, slug:, **goods)
  end

  def lastmod_of(slug)
    served('sitemap-goods-1.xml')[%r{<loc>[^<]*/tovar/#{slug}</loc><lastmod>([^<]+)</lastmod>}, 1]
  end

  describe 'the pages it lists' do
    before do
      stocked('nurofen')
      stocked('pryhovanyi', hidden: true)
      stocked('znyatyi', withdrawn: true)
      create(:catalog_category, slug: 'porozhnia')
      generate
    end

    it 'lists the home page first among the categories and the categories with something to show' do
      expect(served('sitemap-categories-1.xml').scan(%r{<loc>([^<]+)</loc>}).flatten)
        .to eq([ 'https://apteka.h24.ua/', 'https://apteka.h24.ua/katalog/zneboliuvalni' ])
    end

    it 'lists only the products shown on the storefront' do
      expect(served('sitemap-goods-1.xml').scan(%r{<loc>([^<]+)</loc>}).flatten)
        .to eq([ 'https://apteka.h24.ua/tovar/nurofen' ])
    end

    it 'lists neither the cart nor an order', :aggregate_failures do
      all = served('sitemap-categories-1.xml') + served('sitemap-goods-1.xml')

      expect(all).not_to include('/cart')
      expect(all).not_to include('/order')
    end

    it 'points the index at the parts on the front host' do
      expect(served('sitemap.xml').scan(%r{<loc>([^<]+)</loc>}).flatten)
        .to eq(%w[https://apteka.h24.ua/sitemap-categories-1.xml https://apteka.h24.ua/sitemap-goods-1.xml])
    end

    it 'gives the home page no date of change' do
      expect(served('sitemap-categories-1.xml')).to include('<url><loc>https://apteka.h24.ua/</loc></url>')
    end
  end

  it 'splits a kind into parts within the limit and lists them all in the index', :aggregate_failures do
    stub_const('Seo::Sitemaps::Parts::LIMIT', 2)
    allow(Seo::Sitemaps::Parts).to(receive(:new).and_wrap_original { |m, *args| m.call(*args, limit: 2) })
    3.times { stocked("tovar-#{it}") }

    expect(generate).to eq(%w[sitemap-categories-1.xml sitemap-goods-1.xml sitemap-goods-2.xml])
    expect(served('sitemap.xml')).to include('sitemap-goods-2.xml')
  end

  describe 'the date of change' do
    let!(:goods) { stocked('nurofen') }

    it 'stays when a sync wrote nothing new' do
      travel_to(1.day.ago) { generate }
      before_sync = lastmod_of('nurofen')

      goods.save!
      generate

      expect(lastmod_of('nurofen')).to eq(before_sync)
    end

    it 'follows a change of the producer of the group' do
      producer = create(:catalog_producer).tap { goods.goods_group.update!(producer: it) }
      changed_at = 1.hour.from_now.change(usec: 0)
      travel_to(changed_at) { producer.update!(name: 'Reckitt Benckiser') }

      generate

      expect(lastmod_of('nurofen')).to eq(changed_at.utc.iso8601)
    end

    it 'follows a change of the texts set by hand' do
      changed_at = 1.hour.from_now.change(usec: 0)
      travel_to(changed_at) { create(:seo_page_setting, settable: goods, title: 'Нурофен: інструкція') }

      generate

      expect(lastmod_of('nurofen')).to eq(changed_at.utc.iso8601)
    end
  end

  describe 'publishing' do
    it 'keeps the previous version served when a run breaks off', :aggregate_failures do
      stocked('nurofen') && generate
      allow(Seo::Sitemaps::Entries).to receive(:goods).and_raise(ActiveRecord::ConnectionNotEstablished)

      expect { generate }.to raise_error(ActiveRecord::ConnectionNotEstablished)
      expect(served('sitemap-goods-1.xml')).to include('/tovar/nurofen')
      expect(Dir.children(File.join(dir, 'versions')).size).to eq(1)
    end

    it 'keeps only the version served and the one before it' do
      3.times { generate }

      expect(Dir.children(File.join(dir, 'versions')).size).to eq(2)
    end
  end

  it 'refuses to run without a directory' do
    expect { described_class.call(config: Seo::Config.new(front_base_url: 'https://apteka.h24.ua')) }
      .to raise_error(Seo::Config::MissingSetting)
  end
end
