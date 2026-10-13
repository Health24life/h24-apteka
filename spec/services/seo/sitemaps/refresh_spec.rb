# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Sitemaps::Refresh do
  include ActiveSupport::Testing::TimeHelpers

  let(:dir) { Dir.mktmpdir }
  let(:config) { Seo::Config.new(front_base_url: 'https://apteka.h24.ua', sitemap_storage: 'file', sitemap_dir: dir) }
  let(:category) { create(:catalog_category, slug: 'zneboliuvalni') }

  after { FileUtils.rm_rf(dir) }

  def refresh = described_class.call(config:)

  def read(name) = Zlib::GzipReader.open(File.join(dir, 'sitemaps', name), &:read)

  def locs(name) = read(name).scan(%r{<loc>([^<]+)</loc>}).flatten

  def stocked(slug, **goods)
    group = create(:catalog_goods_group)
    create(:catalog_goods_group_category, goods_group: group, category:)
    create(:catalog_goods, goods_group: group, slug:, **goods)
  end

  def lastmod_of(slug) = read('goods.xml.gz')[%r{/tovar/#{slug}</loc>\s*<lastmod>([^<]+)</lastmod>}, 1]

  def limit_parts_to_two
    allow(SitemapGenerator::LinkSet)
      .to(receive(:new).and_wrap_original { |m, opts| m.call(**opts, max_sitemap_links: 2) })
  end

  describe 'the pages it lists' do
    before do
      stocked('nurofen')
      stocked('pryhovanyi', hidden: true)
      stocked('znyatyi', withdrawn: true)
      create(:catalog_category, slug: 'porozhnia')
      refresh
    end

    it 'lists the home page first among the categories and the categories with something to show' do
      expect(locs('categories.xml.gz'))
        .to eq([ 'https://apteka.h24.ua/', 'https://apteka.h24.ua/katalog/zneboliuvalni' ])
    end

    it 'lists only the products shown on the storefront' do
      expect(locs('goods.xml.gz')).to eq([ 'https://apteka.h24.ua/tovar/nurofen' ])
    end

    it 'points the index at the parts on the front host' do
      expect(locs('sitemap.xml.gz'))
        .to eq(%w[https://apteka.h24.ua/sitemaps/categories.xml.gz https://apteka.h24.ua/sitemaps/goods.xml.gz])
    end

    it 'writes neither priority nor change frequency, and no date for the home page', :aggregate_failures do
      expect(read('categories.xml.gz')).not_to match(/<priority>|<changefreq>/)
      expect(read('categories.xml.gz')).to match(%r{<loc>https://apteka.h24.ua/</loc>\s*</url>})
    end
  end

  describe 'an override of robots' do
    it 'leaves out a product an operator took out of the index' do
      create(:seo_override, target: stocked('nurofen'), robots: 'noindex')
      stocked('aspiryn')
      refresh

      expect(locs('goods.xml.gz')).to eq([ 'https://apteka.h24.ua/tovar/aspiryn' ])
    end

    it 'lists a category with nothing to show that an operator opened' do
      create(:seo_override, target: create(:catalog_category, slug: 'sezonni'), robots: 'index')
      refresh

      expect(locs('categories.xml.gz')).to include('https://apteka.h24.ua/katalog/sezonni')
    end

    it 'leaves out a category with products that an operator closed' do
      create(:seo_override, target: category, robots: 'noindex')
      stocked('nurofen') && refresh

      expect(locs('categories.xml.gz')).not_to include('https://apteka.h24.ua/katalog/zneboliuvalni')
    end
  end

  it 'splits a kind into parts within the limit' do
    limit_parts_to_two
    3.times { stocked("tovar-#{it}") }

    expect(refresh).to include('goods.xml.gz', 'goods1.xml.gz')
  end

  it 'removes the parts the new index no longer lists' do
    limit_parts_to_two
    3.times { stocked("tovar-#{it}") } && refresh
    Catalog::Goods.last.update!(hidden: true)

    refresh

    expect(Dir.children(File.join(dir, 'sitemaps'))).to match_array(%w[sitemap.xml.gz categories.xml.gz goods.xml.gz])
  end

  describe 'the date of change' do
    let!(:goods) { stocked('nurofen') }

    def choose_primary(group, category)
      Catalog::PrimaryCategory::Changer.call(group:, category_id: category.id, admin: create(:admin_user))
    end

    it 'stays when a sync wrote nothing new' do
      travel_to(1.day.ago) { refresh }
      before_sync = lastmod_of('nurofen')

      goods.save!
      refresh

      expect(lastmod_of('nurofen')).to eq(before_sync)
    end

    it 'follows a change of the producer of the group' do
      producer = create(:catalog_producer).tap { goods.goods_group.update!(producer: it) }
      changed_at = 1.hour.from_now.change(usec: 0)
      travel_to(changed_at) { producer.update!(name: 'Reckitt Benckiser') }

      refresh

      expect(Time.zone.parse(lastmod_of('nurofen'))).to eq(changed_at)
    end

    it 'follows a change of the texts set by hand' do
      changed_at = 1.hour.from_now.change(usec: 0)
      travel_to(changed_at) { create(:seo_override, target: goods, title_uk: 'Нурофен: інструкція') }

      refresh

      expect(Time.zone.parse(lastmod_of('nurofen'))).to eq(changed_at)
    end

    it 'follows an editor choosing another primary category of the group' do
      other = create(:catalog_goods_group_category, goods_group: goods.goods_group).category
      changed_at = 1.hour.from_now.change(usec: 0)
      travel_to(changed_at) { choose_primary(goods.goods_group, other) }

      refresh

      expect(Time.zone.parse(lastmod_of('nurofen'))).to eq(changed_at)
    end
  end
end
