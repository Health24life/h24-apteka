# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Drugstores with the price of a SKU', :partner_calls do
  let(:Authorization) { nil }
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:id) { linked_goods.id }
  let(:body) { {} }
  let!(:tas) { linked_drugstore('510', name: 'Аптека TAS №118', work_with_reimbursement: true) }

  before do
    use_pharmapoint_config
    use_search_config
  end

  def linked_goods
    goods = create(:catalog_goods)
    Provider::Link.create!(provider:, linkable: goods, external_id: '1750321', synced_at: Time.current)
    goods
  end

  def linked_drugstore(external_id, **)
    drugstore = create(:catalog_drugstore, brand: create(:catalog_drugstore_brand, name: 'Аптека TAS'), **)
    create(:catalog_drugstore_address, drugstore:)
    Provider::Link.create!(provider:, linkable: drugstore, external_id:, synced_at: Time.current)
    drugstore
  end

  def offers_url = pharmapoint_url('order/get-drugstores-for-order-goods')

  def stub_offers(fixture: 'offers_nearby_priced', **answer)
    stub_request(:post, offers_url).with(query: hash_including({})).to_return(pharmapoint_answer(fixture, **answer))
  end

  def error_code = response.parsed_body.dig('error', 'code')

  def drugstores = response.parsed_body['drugstores']

  path '/api/v1/goods/{id}/drugstores' do
    post 'Lists the drugstores around that have a SKU, with its price there' do
      tags 'Drugstores'
      description 'The step that picks the drugstore of the cart: the drugstores around the place that have the ' \
                  'SKU, each with the price in the drugstore and the whole packs it has, asked of the providers ' \
                  'live and never cached. A provider that does not answer gives 503 rather than an empty list. ' \
                  'Only drugstores of the directory are listed, with the legal entity, its EDRPOU code and the week ' \
                  'schedule; one closed now is listed too, with the time it opens. The same for a guest and a ' \
                  'signed-in user.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :id, in: :path, required: true, schema: { type: :integer }, description: 'SKU of the catalog'
      parameter name: :Authorization,
                in: :header,
                required: false,
                schema: { type: :string },
                description: 'Bearer token of a signed-in user; without it the request is served as a guest'
      parameter name: :body, in: :body, required: false, schema: { '$ref' => '#/components/schemas/drugstores_request' }

      response '200', 'the drugstores with the SKU, the cheapest first' do
        schema '$ref' => '#/components/schemas/drugstores_response'
        header 'Cache-Control', schema: { type: :string }, description: '`no-store`: the answer is never cached'

        before { stub_offers }

        run_test! do
          expect(drugstores.sole).to include(
            'id' => tas.id,
            'name' => 'Аптека TAS №118',
            'brand' => { 'name' => 'Аптека TAS' },
            'legal_entity' => { 'name' => 'ТОВ «Аптека»', 'code' => '01234567' },
            'distance' => 2216,
            'open_now' => true,
            'opens_at' => nil,
            'goods' => { 'price' => '162.50', 'available_quantity' => 3 }
          )
        end
      end

      response '200', 'nothing around has the SKU: an empty list, not an error' do
        schema '$ref' => '#/components/schemas/drugstores_response'

        before { stub_offers(fixture: 'offers_nearby') }

        run_test! { expect(drugstores).to eq([]) }
      end

      response '200', 'only the drugstores of the program «Доступні ліки», by distance' do
        schema '$ref' => '#/components/schemas/drugstores_response'

        let(:body) { { sort: 'distance', work_with_reimbursement: true } }

        before do
          tas.update!(work_with_reimbursement: false)
          stub_offers
        end

        run_test! { expect(drugstores).to eq([]) }
      end

      response '401', 'an expired or invalid token' do
        schema '$ref' => '#/components/schemas/error'

        let(:Authorization) { 'Bearer not-a-jwt' }

        run_test! { expect(error_code).to eq('unauthorized') }
      end

      response '404', 'goods_not_found: no such SKU, or it or its group is hidden or withdrawn' do
        schema '$ref' => '#/components/schemas/error'

        let(:id) { create(:catalog_goods, hidden: true).id }

        run_test! { expect(error_code).to eq('goods_not_found') }
      end

      response '422', 'invalid_location: a latitude without a longitude, or a radius out of bounds' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { location: { latitude: 50.45 } } }

        run_test! { expect(error_code).to eq('invalid_location') }
      end

      response '422', 'invalid_sort: a sort other than price or distance' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { sort: 'rating' } }

        run_test! { expect(error_code).to eq('invalid_sort') }
      end

      response '422', 'invalid_reimbursement: work_with_reimbursement other than true or false' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { work_with_reimbursement: 'true' } }

        run_test! { expect(error_code).to eq('invalid_reimbursement') }
      end

      response '503', 'drugstores_unavailable: the provider did not answer, answered an error or has no key' do
        schema '$ref' => '#/components/schemas/error'

        before { stub_request(:post, offers_url).with(query: hash_including({})).to_timeout }

        run_test! do
          expect(response.parsed_body['error']).to eq(
            'code' => 'drugstores_unavailable',
            'message' => 'Ціни в аптеках тимчасово недоступні. Спробуйте пізніше.'
          )
        end
      end

      response '503', 'drugstores_busy: the request limit is used up; Retry-After tells when to try again' do
        schema '$ref' => '#/components/schemas/error'
        header 'Retry-After', schema: { type: :integer }, description: 'Seconds to wait before asking again'

        before { stub_offers(body: '{}', status: 429, headers: { 'Retry-After' => '12' }) }

        run_test! do
          expect([ error_code, response.headers['Retry-After'] ]).to eq(%w[drugstores_busy 12])
        end
      end
    end
  end
end
