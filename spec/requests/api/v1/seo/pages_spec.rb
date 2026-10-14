# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'SEO data of a page' do
  let(:Authorization) { nil }

  before do
    Seo::Templates::Defaults.call
    create(:catalog_goods, name_uk: 'Нурофен', slug: 'nurofen', dosage: '200 мг')
  end

  path '/api/v1/seo/page' do
    get 'Status, redirect, meta tags, robots, breadcrumbs and the text of a static page of the front' do
      tags 'SEO'
      description 'Built from the Health24 database only: the partner is never asked, and the answer is the same ' \
                  'for a guest and a signed-in user. The state of the page is in `status`; the HTTP status is 200 ' \
                  'for any path that could be read. A single segment that no other route takes is the address of a ' \
                  'static page, whose text comes in `content`.'
      produces 'application/json'
      parameter name: :path, in: :query, required: true, schema: { type: :string, maxLength: 2048 },
                example: '/katalog/liky?page=2', description: 'Path of the front page as in the browser, with its query'
      parameter name: :Authorization, in: :header, required: false, schema: { type: :string },
                description: 'Bearer token of a signed-in user; without it the request is served as a guest'

      response '200', 'a page that is there' do
        schema '$ref' => '#/components/schemas/seo_page'
        header 'X-Robots-Tag', schema: { type: :string }, description: 'Always `noindex, follow`: no API is indexed'
        let(:path) { '/tovar/nurofen?utm_source=fb' }

        let(:breadcrumbs) do
          [ { 'name' => 'Головна', 'path' => '/' }, { 'name' => 'Нурофен', 'path' => '/tovar/nurofen' } ]
        end

        run_test! do
          expect(response.parsed_body).to include(
            'status' => 200, 'location' => nil, 'title' => 'Нурофен 200 мг — інструкція із застосування',
            'h1' => 'Нурофен 200 мг', 'robots' => 'index, follow', 'seo_text' => nil, 'breadcrumbs' => breadcrumbs,
            'content' => nil
          )
        end
      end

      response '200', 'a static page with its text' do
        schema '$ref' => '#/components/schemas/seo_page'
        let(:path) { '/umovy-servisu' }

        before do
          create(:seo_static_page, :published, name_uk: 'Умови сервісу',
                                               content_uk: '<p>Бронювання без передоплати.</p>')
        end

        run_test! do
          expect(response.parsed_body).to include(
            'status' => 200, 'h1' => 'Умови сервісу', 'content' => '<p>Бронювання без передоплати.</p>'
          )
        end
      end

      response '200', 'a withdrawn product an editor leads to a category' do
        schema '$ref' => '#/components/schemas/seo_page'
        let(:path) { '/tovar/nurofen-stare' }

        before do
          create(:catalog_goods, slug: 'nurofen-stare', withdrawn: true)
          create(:seo_redirect, manual: true, page_type: 'goods', slug: 'nurofen-stare',
                                redirectable: create(:catalog_category, slug: 'zneboliuvalni'))
        end

        run_test! do
          expect(response.parsed_body).to include('status' => 301, 'location' => '/katalog/zneboliuvalni')
        end
      end

      response '200', 'a path that redirects' do
        schema '$ref' => '#/components/schemas/seo_page'
        let(:path) { '/TOVAR/nurofen/' }

        run_test! do
          expect(response.parsed_body).to include('status' => 301, 'location' => '/tovar/nurofen', 'title' => nil)
        end
      end

      response '200', 'a page that is not there' do
        schema '$ref' => '#/components/schemas/seo_page'
        let(:path) { '/tovar/nema-takoho' }

        run_test! do
          expect(response.parsed_body).to include('status' => 404, 'robots' => 'noindex, nofollow', 'breadcrumbs' => [])
        end
      end

      response '200', 'a product the provider withdrew' do
        schema '$ref' => '#/components/schemas/seo_page'
        let(:path) { "/tovar/#{create(:catalog_goods, withdrawn: true).slug}" }

        run_test! do
          expect(response.parsed_body['status']).to eq(410)
        end
      end

      response '200', 'the same answer for a signed-in user' do
        schema '$ref' => '#/components/schemas/seo_page'
        let(:path) { '/tovar/nurofen' }
        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }

        run_test! do
          signed_in = response.parsed_body
          get '/api/v1/seo/page', params: { path: '/tovar/nurofen' }

          expect(response.parsed_body).to eq(signed_in)
        end
      end

      response '422', 'a path that is not a page path' do
        schema '$ref' => '#/components/schemas/error'
        let(:path) { 'tovar/nurofen' }

        run_test! do
          expect(response.parsed_body.dig('error', 'code')).to eq('invalid_path')
        end
      end

      response '401', 'an expired or invalid token' do
        schema '$ref' => '#/components/schemas/error'
        let(:path) { '/tovar/nurofen' }
        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42, exp: 1.hour.ago.to_i)}" }

        run_test! do
          expect(response.parsed_body['error']).to eq(
            'code' => 'unauthorized', 'message' => 'Сесія недійсна або завершилася. Увійдіть знову.'
          )
        end
      end
    end
  end

  describe 'the session' do
    it 'reads no token from a cookie' do
      cookies['.AspNet.ApplicationCookie'] = 'not-a-token'

      get '/api/v1/seo/page', params: { path: '/' }

      expect(response).to have_http_status(:ok)
    end

    it 'refuses a missing path with the error format of the API', :aggregate_failures do
      get '/api/v1/seo/page'

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('error', 'code')).to eq('invalid_path')
    end

    it 'refuses a path longer than the limit' do
      get '/api/v1/seo/page', params: { path: "/#{'a' * 2048}" }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
