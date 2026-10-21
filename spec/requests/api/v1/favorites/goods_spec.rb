# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe '«Мої товари»' do
  let(:user_id) { 42 }
  let(:Authorization) { "Bearer #{generate_jwt_token(nameid: user_id)}" }
  let(:goods) { create(:catalog_goods, dosage: '400 мг', release_form: 'таблетки') }
  let(:goods_id) { goods.id }

  def error_code = response.parsed_body.dig('error', 'code')

  def kept = Favorite::Goods.where(user_id:).pluck(:goods_id)

  shared_examples 'a guest is refused' do
    response '401', 'unauthorized: no session, as the list belongs to an account' do
      schema '$ref' => '#/components/schemas/error'

      let(:Authorization) { nil }

      run_test! { expect(error_code).to eq('unauthorized') }
    end
  end

  path '/api/v1/favorites/goods' do
    get 'Lists «Мої товари» of the signed-in user' do
      tags 'Favorites'
      description 'The SKU the user keeps, the last added first, with the static data of their cards and no prices: ' \
                  'a price belongs to a drugstore. A SKU hidden or withdrawn later stays, with `available: false`. ' \
                  'The provider is not asked.'
      produces 'application/json'
      parameter name: :Authorization,
                in: :header,
                required: true,
                schema: { type: :string },
                description: 'Bearer token of the signed-in user'

      response '200', 'the SKU of the list, the last added first, the hidden one marked unavailable' do
        schema '$ref' => '#/components/schemas/favorite_goods_response'

        let(:hidden) { create(:catalog_goods, hidden: true) }

        before do
          create(:favorite_goods, user_id:, goods:, created_at: 2.days.ago)
          create(:favorite_goods, user_id:, goods: hidden, created_at: 1.day.ago)
          create(:favorite_goods, user_id: 7)
        end

        run_test! do
          expect(response.parsed_body['goods'].map { it.slice('id', 'available', 'dosage', 'release_form') }).to eq(
            [
              {
                'id' => hidden.id,
                'available' => false,
                'dosage' => hidden.dosage,
                'release_form' => hidden.release_form
              },
              { 'id' => goods.id, 'available' => true, 'dosage' => '400 мг', 'release_form' => 'таблетки' }
            ]
          )
        end
      end

      it_behaves_like 'a guest is refused'
    end
  end

  path '/api/v1/favorites/goods/{goods_id}' do
    parameter name: :goods_id, in: :path, required: true, schema: { type: :integer }, description: 'SKU of the catalog'
    parameter name: :Authorization,
              in: :header,
              required: true,
              schema: { type: :string },
              description: 'Bearer token of the signed-in user'

    put 'Puts a SKU in «Мої товари»' do
      tags 'Favorites'
      description 'A release form, dosage and pack, not a trade name. Adding a SKU already in the list is no error ' \
                  'and keeps its place, even in a full list. A list holds up to 100 SKU.'

      response '204', 'the SKU is in the list, once, also when it was there already' do
        before { create(:favorite_goods, user_id:, goods:, created_at: 1.day.ago) }

        run_test! { expect(kept).to eq([ goods.id ]) }
      end

      response '404', 'goods_not_found: no such SKU, or it or its group is hidden or withdrawn' do
        schema '$ref' => '#/components/schemas/error'

        let(:goods_id) { create(:catalog_goods, withdrawn: true).id }

        run_test! { expect(error_code).to eq('goods_not_found') }
      end

      response '422', 'favorites_limit_reached: the list holds the most it may; details.limit tells how many' do
        schema '$ref' => '#/components/schemas/error'

        before do
          stub_const('Favorites::LIMIT', 1)
          create(:favorite_goods, user_id:)
        end

        run_test! do
          expect(response.parsed_body['error']).to include(
            'code' => 'favorites_limit_reached',
            'details' => { 'limit' => 1 }
          )
        end
      end

      it_behaves_like 'a guest is refused'
    end

    delete 'Takes a SKU out of «Мої товари»' do
      tags 'Favorites'
      description 'Also a SKU the catalog no longer shows. Taking out a SKU that is not in the list is no error.'

      response '204', 'the SKU is out of the list, also when it was not there' do
        before { create(:favorite_goods, user_id:, goods:) }

        run_test! { expect(kept).to eq([]) }
      end

      it_behaves_like 'a guest is refused'
    end
  end
end
