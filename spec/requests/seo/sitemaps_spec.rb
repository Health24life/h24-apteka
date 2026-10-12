# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Sitemap' do
  let(:dir) { Dir.mktmpdir }
  let(:config) { Seo::Config.new(front_base_url: 'https://apteka.h24.ua', sitemap_dir: dir) }

  before { allow(Seo::Config).to receive(:current).and_return(config) }
  after { FileUtils.rm_rf(dir) }

  path '/sitemap.xml' do
    get 'The sitemap index of the section' do
      tags 'Sitemap'
      description 'Served from the root of the API host, outside /api/v1; the front proxies its own /sitemap.xml ' \
                  'here. The parts it lists are on the front host.'
      produces 'application/xml'

      response '200', 'the index of the last generated sitemap' do
        before { Seo::Sitemaps::Generate.call }

        run_test! do
          expect(response.body).to include('<sitemapindex', 'https://apteka.h24.ua/sitemap-categories-1.xml')
        end
      end

      response '404', 'no sitemap generated yet' do
        run_test!
      end
    end
  end

  path '/sitemap-{part}.xml' do
    parameter name: :part, in: :path, required: true, schema: { type: :string, pattern: '^[a-z0-9-]+$' },
              example: 'goods-1', description: 'Kind of pages and the number of the part'

    get 'A part of the sitemap' do
      tags 'Sitemap'
      produces 'application/xml'

      response '200', 'the URLs of the part' do
        let(:part) { 'categories-1' }

        before { Seo::Sitemaps::Generate.call }

        run_test! do
          expect(response.body).to include('<urlset', '<loc>https://apteka.h24.ua/</loc>')
        end
      end

      response '404', 'a part the sitemap does not have' do
        let(:part) { 'goods-9' }

        before { Seo::Sitemaps::Generate.call }

        run_test!
      end
    end
  end
end
