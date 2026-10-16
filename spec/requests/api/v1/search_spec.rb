# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Search of goods', :partner_calls do
  let(:Authorization) { nil }
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:body) { { queries: [ { text: 'спазмалгон' } ] } }

  before do
    use_pharmapoint_config
    use_search_config
  end

  def search_url = pharmapoint_url('goods-group/search')

  def stub_search(**answer)
    stub = stub_request(:get, search_url).with(query: hash_including({}))
    stub.to_return(pharmapoint_answer(nil, body: pharmapoint_fixture('goods_group_search_by_query'), **answer))
  end

  def stub_empty_search = stub_search(body: { data: [], meta: { page: 1, per_page: 20, total: 0 } }.to_json)

  def link(record, external_id)
    Provider::Link.create!(provider:, linkable: record, external_id:, synced_at: Time.current)
    record
  end

  def error_code = response.parsed_body.dig('error', 'code')

  def results = response.parsed_body['results']

  # A provider whose search never answers.
  def unavailable_adapter
    Class.new do
      attr_reader :provider

      def initialize(provider:, **) = @provider = provider

      def call(*, **) = Catalog::Search::Failure.new(provider: provider.code, reason: :unavailable, retry_after: nil)
    end
  end

  path '/api/v1/search' do
    post 'Searches the providers live for goods by name' do
      tags 'Search'
      description 'Every query is searched live in the providers, never in the local catalog: a SKU only the catalog ' \
                  'has is not listed, and a provider that does not answer gives 503 rather than an empty list. A row ' \
                  'is a release form (SKU) without prices, stock or images; one the catalog does not show yet comes ' \
                  'with `ready: false` and no address of its card. What is found is saved to the catalog in the ' \
                  'background, so a later search lists it as ready. A page counts goods groups, not rows. Call it on ' \
                  'submit, not on every key. The same for a guest and a signed-in user.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :Authorization,
                in: :header,
                required: false,
                schema: { type: :string },
                description: 'Bearer token of a signed-in user; without it the request is served as a guest'
      parameter name: :body, in: :body, required: true, schema: { '$ref' => '#/components/schemas/search_request' }

      response '200', 'the release forms found, saved ones leading to their cards' do
        schema '$ref' => '#/components/schemas/search_response'
        header 'Cache-Control', schema: { type: :string }, description: '`no-store`: the answer is never cached'

        let!(:saved) { link(create(:catalog_goods, name_uk: 'Спазмалгон табл. №50'), '1795034') }

        before do
          stub_search
          link(create(:catalog_goods, hidden: true), '1795036')
        end

        run_test! do
          expect(results.sole['goods'].map { it.values_at('ref', 'ready', 'id', 'slug') }).to eq(
            [
              [ 'pharmapoint:a060d7776d3d256af22378e018bea336:1795034', true, saved.id, saved.slug ],
              [ 'pharmapoint:a060d7776d3d256af22378e018bea336:1795035', false, nil, nil ],
              [ 'pharmapoint:122c4abff4ae26d0068e7b4cfce236a6:2001001', false, nil, nil ]
            ]
          )
        end
      end

      response '200', 'nothing found is an empty list, not an error' do
        schema '$ref' => '#/components/schemas/search_response'

        before { stub_empty_search }

        run_test! do
          expect(results.sole).to include('status' => 'ok', 'goods' => [], 'total_groups' => 0)
        end
      end

      response '200',
               'some providers did not answer: the goods of the others, naming those that did not' do
        schema '$ref' => '#/components/schemas/search_response'

        before do
          stub_search
          create(:provider, code: 'other')
          stub_const(
            'Catalog::Search::Adapters::BY_CODE',
            { 'pharmapoint' => Pharmapoint::Search, 'other' => unavailable_adapter }
          )
          use_search_config(providers: 'pharmapoint,other')
        end

        run_test! do
          expect(results.sole).to include(
            'status' => 'partial',
            'unavailable_providers' => %w[other],
            'goods' => have_attributes(size: 4)
          )
        end
      end

      response '200', 'a signed-in user gets what a guest gets' do
        schema '$ref' => '#/components/schemas/search_response'

        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }

        before { stub_search }

        run_test! do
          expect(results.sole['goods'].size).to eq(4)
        end
      end

      response '401', 'an expired or invalid token' do
        schema '$ref' => '#/components/schemas/error'

        let(:Authorization) { 'Bearer not-a-jwt' }

        run_test! do
          expect(error_code).to eq('unauthorized')
        end
      end

      response '422', 'queries is not an array of one to the allowed number of queries' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { queries: [ { text: 'спазмалгон' }, { text: 'цитрамон' } ] } }

        run_test! do
          expect(response.parsed_body['error']).to eq(
            'code' => 'invalid_search_queries',
            'message' => 'Передайте масив queries з одного або кількох пошукових запитів, але не більше дозволеного.'
          )
        end
      end

      response '422', 'a text shorter than 3 or longer than 100 characters' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { queries: [ { text: '  ab  ' } ] } }

        run_test! do
          expect(error_code).to eq('invalid_search_text')
        end
      end

      response '422', 'a page that is not a whole number from 1 to 50' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { queries: [ { text: 'спазмалгон', page: 51 } ] } }

        run_test! { expect(error_code).to eq('invalid_search_page') }
      end

      response '422', 'a latitude without a longitude, or a radius out of bounds' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { queries: [ { text: 'спазмалгон', location: { latitude: 50.45 } } ] } }

        run_test! { expect(error_code).to eq('invalid_search_location') }
      end

      response '503', 'search_unavailable: the provider did not answer, answered an error or has no key' do
        schema '$ref' => '#/components/schemas/error'

        before { stub_request(:get, search_url).with(query: hash_including({})).to_timeout }

        run_test! do
          expect(response.parsed_body['error']).to eq(
            'code' => 'search_unavailable', 'message' => 'Пошук тимчасово недоступний. Спробуйте пізніше.'
          )
        end
      end

      response '503',
               'search_busy: the request limit is used up; Retry-After tells when to try again' do
        schema '$ref' => '#/components/schemas/error'
        header 'Retry-After', schema: { type: :integer }, description: 'Seconds to wait before searching again'

        before { stub_search(body: '{}', status: 429, headers: { 'Retry-After' => '12' }) }

        run_test! do
          expect([ error_code, response.headers['Retry-After'] ]).to eq(%w[search_busy 12])
        end
      end
    end
  end

  describe 'beyond the documented answers' do
    def search(queries = body[:queries])
      post '/api/v1/search', params: { queries: }.to_json, headers: { 'Content-Type' => 'application/json' }
    end

    def requested_around(**place) = a_request(:get, search_url).with(query: hash_including(place))

    it 'logs the call of a signed-in user as a search of theirs' do
      stub_search

      post '/api/v1/search',
           params: body.to_json,
           headers: {
             'Content-Type' => 'application/json',
             'Authorization' => "Bearer #{generate_jwt_token(nameid: 42)}"
           }

      expect(Provider::RequestLog.last).to have_attributes(category: 'search', user_id: 42)
    end

    it 'asks the provider nothing for a request it refuses', :aggregate_failures do
      search([ { text: 'ab' } ])
      post '/api/v1/search',
           params: body.to_json,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => 'Bearer bad' }

      expect(response).to have_http_status(:unauthorized)
      expect(a_request(:get, search_url).with(query: hash_including({}))).not_to have_been_requested
    end

    it 'tells the page of goods groups and the providers that answered' do
      stub_search

      search

      expect(results.sole).to include(
        'query' => 'спазмалгон',
        'status' => 'ok',
        'unavailable_providers' => [],
        'page' => 1,
        'per_page' => 20,
        'total_groups' => 2,
        'has_more' => false
      )
    end

    it 'gives the static card of a row, with the code of the country only' do
      stub_search

      search

      expect(results.sole['goods'].first).to include(
        'name' => 'Спазмалгон табл. №50(10х5)',
        'trade_name' => 'Спазмалгон',
        'producer' => { 'name' => 'Balkanpharma', 'country_code' => 'BG' },
        'group' => { 'ref' => 'pharmapoint:a060d7776d3d256af22378e018bea336', 'name' => 'Спазмалгон табл. №50(10х5)' }
      )
    end

    it 'gives no prices, stock or images, though the provider sent them' do
      stub_search

      search

      expect(results.sole['goods'].flat_map(&:keys)).not_to include('online_price', 'quantity', 'nds', 'image_paths')
    end

    it 'is never cached' do
      stub_search

      search

      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'asks the provider around the place of the user, rounded to about a kilometre' do
      stub_search

      search([ { text: 'спазмалгон', location: { latitude: 50.45012, longitude: 30.52741, radius: 5000 } } ])

      expect(requested_around(latitude: '50.45', longitude: '30.53', radius: '5000')).to have_been_requested
    end

    it 'asks around the configured point and radius without a place' do
      stub_search
      use_search_config(location: { latitude: 49.8397, longitude: 24.0297, radius: 30_000 })

      search

      expect(requested_around(latitude: '49.84', longitude: '24.03', radius: '30000')).to have_been_requested
    end

    it 'refuses a radius larger than the maximum' do
      use_search_config(location: { max_radius: 50_000 })

      search([ { text: 'спазмалгон', location: { radius: 50_001 } } ])

      expect(error_code).to eq('invalid_search_location')
    end

    it 'refuses a page or a radius that is not a whole number', :aggregate_failures do
      search([ { text: 'спазмалгон', page: '2' } ])
      expect(error_code).to eq('invalid_search_page')

      search([ { text: 'спазмалгон', location: { radius: 0 } } ])
      expect(error_code).to eq('invalid_search_location')
    end

    it 'refuses queries given as a string or as an empty array', :aggregate_failures do
      search('спазмалгон')
      expect(error_code).to eq('invalid_search_queries')

      search([])
      expect(error_code).to eq('invalid_search_queries')
    end

    it 'answers 503 without a key of the provider' do
      use_pharmapoint_config(connection: { api_key: '' })
      allow(Rails.error).to receive(:report)

      search

      expect(error_code).to eq('search_unavailable')
    end

    it 'answers 503 when the search of every provider is turned off, and the provider stays enabled',
       :aggregate_failures do
      use_search_config(providers: '')

      search

      expect(error_code).to eq('search_unavailable')
      expect(provider.reload.active).to be(true)
    end

    it 'does not list a SKU only the catalog has' do
      stub_empty_search
      link(create(:catalog_goods, name_uk: 'Спазмалгон'), 'only-local')

      search

      expect(results.sole['goods']).to be_empty
    end

    it 'queues what it found to be saved' do
      stub_search

      search

      expect(Catalog::Sync::PullWorker.jobs.pluck('args').map(&:second))
        .to contain_exactly('a060d7776d3d256af22378e018bea336', '122c4abff4ae26d0068e7b4cfce236a6')
    end

    it 'lists a SKU as ready once it is saved', :aggregate_failures do
      stub_search
      search
      expect(results.sole['goods'].last).to include('ready' => false)

      link(create(:catalog_goods), '2001001') && search
      expect(results.sole['goods'].last).to include('ready' => true)
    end

    it 'never calls the provider a second time within a request' do
      stub = stub_request(:get, search_url).with(query: hash_including({})).to_return(status: 502, body: 'Bad gateway')

      search

      expect(stub).to have_been_requested.once
    end

    it 'keeps the text of the search out of the application log' do
      expect(ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(body))
        .to eq(queries: '[FILTERED]')
    end
  end
end
