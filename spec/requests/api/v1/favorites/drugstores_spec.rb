# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe '«Мої аптеки»' do
  let(:user_id) { 42 }
  let(:Authorization) { "Bearer #{generate_jwt_token(nameid: user_id)}" }
  let(:drugstore) do
    create(:catalog_drugstore, name: 'Аптека TAS №118').tap { create(:catalog_drugstore_address, drugstore: it) }
  end
  let(:drugstore_id) { drugstore.id }

  def error_code = response.parsed_body.dig('error', 'code')

  def kept = Favorite::Drugstore.where(user_id:).pluck(:drugstore_id)

  shared_examples 'a guest is refused' do
    response '401', 'unauthorized: no session, as the list belongs to an account' do
      schema '$ref' => '#/components/schemas/error'

      let(:Authorization) { nil }

      run_test! { expect(error_code).to eq('unauthorized') }
    end
  end

  path '/api/v1/favorites/drugstores' do
    get 'Lists «Мої аптеки» of the signed-in user' do
      tags 'Favorites'
      description 'The drugstores the user keeps, the last added first, with the legal entity, its EDRPOU code and ' \
                  'the working hours, as a drugstore is shown everywhere. A drugstore hidden or withdrawn later ' \
                  'stays, with `available: false`. The provider is not asked.'
      produces 'application/json'
      parameter name: :Authorization,
                in: :header,
                required: true,
                schema: { type: :string },
                description: 'Bearer token of the signed-in user'

      response '200', 'the drugstores of the list, the last added first, the withdrawn one marked unavailable' do
        schema '$ref' => '#/components/schemas/favorite_drugstores_response'

        let(:withdrawn) { create(:catalog_drugstore, withdrawn: true) }

        before do
          create(:favorite_drugstore, user_id:, drugstore:, created_at: 2.days.ago)
          create(:favorite_drugstore, user_id:, drugstore: withdrawn, created_at: 1.day.ago)
        end

        run_test! do
          fields = %w[id available name drugstore_legal_entity_name drugstore_legal_entity_code]
          expect(response.parsed_body['drugstores'].map { it.slice(*fields) }).to eq(
            [
              {
                'id' => withdrawn.id,
                'available' => false,
                'name' => nil,
                'drugstore_legal_entity_name' => 'ТОВ «Аптека»',
                'drugstore_legal_entity_code' => '01234567'
              },
              {
                'id' => drugstore.id,
                'available' => true,
                'name' => 'Аптека TAS №118',
                'drugstore_legal_entity_name' => 'ТОВ «Аптека»',
                'drugstore_legal_entity_code' => '01234567'
              }
            ]
          )
        end
      end

      it_behaves_like 'a guest is refused'
    end
  end

  path '/api/v1/favorites/drugstores/{drugstore_id}' do
    parameter name: :drugstore_id, in: :path, required: true, schema: { type: :integer }
    parameter name: :Authorization,
              in: :header,
              required: true,
              schema: { type: :string },
              description: 'Bearer token of the signed-in user'

    put 'Puts a drugstore in «Мої аптеки»' do
      tags 'Favorites'
      description 'Adding a drugstore already in the list is no error and keeps its place, even in a full list. A ' \
                  'list holds up to 100 drugstores.'

      response '204', 'the drugstore is in the list' do
        run_test! { expect(kept).to eq([ drugstore.id ]) }
      end

      response '404', 'drugstore_not_found: no such drugstore, or it is hidden or withdrawn' do
        schema '$ref' => '#/components/schemas/error'

        let(:drugstore_id) { create(:catalog_drugstore, hidden: true).id }

        run_test! { expect(error_code).to eq('drugstore_not_found') }
      end

      response '422', 'favorites_limit_reached: the list holds the most it may; details.limit tells how many' do
        schema '$ref' => '#/components/schemas/error'

        before do
          stub_const('Favorites::LIMIT', 1)
          create(:favorite_drugstore, user_id:)
        end

        run_test! { expect(error_code).to eq('favorites_limit_reached') }
      end

      it_behaves_like 'a guest is refused'
    end

    delete 'Takes a drugstore out of «Мої аптеки»' do
      tags 'Favorites'
      description 'Also a drugstore the directory no longer shows. Taking out one that is not in the list is no error.'

      response '204', 'the drugstore is out of the list' do
        before { create(:favorite_drugstore, user_id:, drugstore:) }

        run_test! { expect(kept).to eq([]) }
      end

      it_behaves_like 'a guest is refused'
    end
  end
end
