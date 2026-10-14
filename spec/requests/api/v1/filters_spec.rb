# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'SEO filters' do
  let(:Authorization) { nil }
  let(:vitamins) { create(:catalog_category, name_uk: 'Вітаміни', slug: 'vitaminy') }

  path '/api/v1/filters' do
    get 'The published filters of a category, or of the home page of the section' do
      tags 'SEO filters'
      description 'For the block of selections on the page of a category; without `category_id`, on the home page ' \
                  'of the section. Published filters that are not removed only, in the order the editor set. Built ' \
                  'from the Health24 database only, the same for a guest and a signed-in user.'
      produces 'application/json'
      parameter name: :category_id, in: :query, required: false, schema: { type: :integer, minimum: 1 },
                description: 'Category whose filters are listed; without it, the filters of the home page'
      parameter name: :Authorization, in: :header, required: false, schema: { type: :string },
                description: 'Bearer token of a signed-in user; without it the request is served as a guest'

      response '200', 'the filters of a category in their order' do
        schema '$ref' => '#/components/schemas/seo_filter_list'
        let(:category_id) { vitamins.id }

        before do
          create(:seo_filter, :published, name_uk: 'Вітаміни для дітей', category: vitamins, position: 2)
          create(:seo_filter, :published, name_uk: 'Вітамін D', category: vitamins, position: 1)
          create(:seo_filter, name_uk: 'Для імунітету', category: vitamins)
          create(:seo_filter, :published, name_uk: 'Від застуди', category: vitamins).remove!
          create(:seo_filter, :published, name_uk: 'Від застуди без рецепта')
        end

        run_test! do
          expect(response.parsed_body['filters'].pluck('name', 'slug', 'path')).to eq(
            [ [ 'Вітамін D', 'vitamin-d', '/dobirka/vitamin-d' ],
              [ 'Вітаміни для дітей', 'vitaminy-dlia-ditei', '/dobirka/vitaminy-dlia-ditei' ] ]
          )
        end
      end

      response '200', 'the filters of the home page of the section' do
        schema '$ref' => '#/components/schemas/seo_filter_list'
        let(:category_id) { nil }

        before do
          create(:seo_filter, :published, name_uk: 'Від застуди без рецепта')
          create(:seo_filter, :published, name_uk: 'Вітамін D', category: vitamins)
        end

        run_test! do
          expect(response.parsed_body['filters'].pluck('path')).to eq([ '/dobirka/vid-zastudy-bez-retsepta' ])
        end
      end

      response '200', 'no filters for a category that is not there' do
        schema '$ref' => '#/components/schemas/seo_filter_list'
        let(:category_id) { 999_999 }

        run_test! do
          expect(response.parsed_body).to eq('filters' => [])
        end
      end

      response '422', 'a category id that is not a positive integer' do
        schema '$ref' => '#/components/schemas/error'
        let(:category_id) { 'vitaminy' }

        run_test! do
          expect(response.parsed_body['error']).to eq(
            'code' => 'invalid_category_id', 'message' => 'Параметр category_id має бути додатним цілим числом.'
          )
        end
      end
    end
  end

  path '/api/v1/filters/{id}' do
    get 'A published filter by its current address, with the badges of its parameters' do
      tags 'SEO filters'
      description 'The page of a filter at `/dobirka/<slug>`. `params` are kept as the catalog search takes them; ' \
                  '`applied_params` name them and their values for the badges of the page. The goods of the filter ' \
                  'come with the catalog search. An old address answers 404: the SEO endpoint redirects it first.'
      produces 'application/json'
      parameter name: :id, in: :path, required: true, schema: { type: :string }, example: 'vitaminy-dlia-ditei',
                description: 'Current address (slug) of the filter'
      parameter name: :Authorization, in: :header, required: false, schema: { type: :string },
                description: 'Bearer token of a signed-in user; without it the request is served as a guest'

      let(:capsules) { create(:catalog_goods_form, name_uk: 'Капсули') }
      let!(:filter) do
        create(:seo_filter, :published, name_uk: 'Вітаміни для дітей', category: vitamins, sort_order: 'newest',
                                        params: { 'category_id' => [ vitamins.id ], 'form_id' => [ capsules.id ] })
      end

      response '200', 'a published filter' do
        schema '$ref' => '#/components/schemas/seo_filter'
        let(:id) { 'vitaminy-dlia-ditei' }

        def card
          { 'id' => filter.id, 'name' => 'Вітаміни для дітей', 'slug' => 'vitaminy-dlia-ditei',
            'path' => '/dobirka/vitaminy-dlia-ditei', 'sort_order' => 'newest', 'recipe_scope' => 'otc',
            'category' => { 'id' => vitamins.id, 'name' => 'Вітаміни', 'path' => '/katalog/vitaminy' },
            'params' => { 'category_id' => [ vitamins.id ], 'form_id' => [ capsules.id ] },
            'applied_params' => [
              { 'key' => 'category_id', 'name' => 'Категорія',
                'values' => [ { 'id' => vitamins.id, 'name' => 'Вітаміни' } ] },
              { 'key' => 'form_id', 'name' => 'Форма випуску',
                'values' => [ { 'id' => capsules.id, 'name' => 'Капсули' } ] }
            ] }
        end

        run_test! do
          expect(response.parsed_body).to eq(card)
        end
      end

      response '200', 'a filter without a category' do
        schema '$ref' => '#/components/schemas/seo_filter'
        let(:id) { 'Vitaminy-Dlia-Ditei' }

        before { filter.update!(category: nil) }

        run_test! do
          expect(response.parsed_body).to include('category' => nil, 'slug' => 'vitaminy-dlia-ditei')
        end
      end

      response '200', 'the same answer for a signed-in user' do
        schema '$ref' => '#/components/schemas/seo_filter'
        let(:id) { 'vitaminy-dlia-ditei' }
        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }

        run_test! do
          signed_in = response.parsed_body
          get '/api/v1/filters/vitaminy-dlia-ditei'

          expect(response.parsed_body).to eq(signed_in)
        end
      end

      response '404', 'a filter that is not published' do
        schema '$ref' => '#/components/schemas/error'
        let(:id) { 'vitaminy-dlia-ditei' }

        before { filter.update!(published: false) }

        run_test! do
          expect(response.parsed_body['error']).to eq('code' => 'filter_not_found', 'message' => 'Добірку не знайдено.')
        end
      end

      response '404', 'a removed filter' do
        schema '$ref' => '#/components/schemas/error'
        let(:id) { 'vitaminy-dlia-ditei' }

        before { filter.remove! }

        run_test! do
          expect(response.parsed_body.dig('error', 'code')).to eq('filter_not_found')
        end
      end

      response '404', 'an old address of a filter' do
        schema '$ref' => '#/components/schemas/error'
        let(:id) { 'vitaminy-dlia-ditei' }

        before { filter.update!(slug: 'vitaminy-ditiam') }

        run_test! do
          expect(response.parsed_body.dig('error', 'code')).to eq('filter_not_found')
        end
      end

      response '404', 'an address no filter has' do
        schema '$ref' => '#/components/schemas/error'
        let(:id) { 'nema-takoi' }

        run_test!
      end
    end
  end
end
