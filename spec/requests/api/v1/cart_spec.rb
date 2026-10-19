# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'The cart', :partner_calls do
  let(:Authorization) { nil }
  let(:'X-Cart-Token') { cart.token }
  let!(:provider) { create(:provider, code: 'pharmapoint') }
  let(:cart) { create(:order, provider:) }

  before do
    use_pharmapoint_config
    stub_drugstore_offers
  end

  def error_code = response.parsed_body.dig('error', 'code')

  path '/api/v1/cart' do
    parameter name: :Authorization,
              in: :header,
              required: false,
              schema: { type: :string },
              description: 'Bearer token of a signed-in user, whose account has the cart'
    parameter name: :'X-Cart-Token',
              in: :header,
              required: false,
              schema: { type: :string },
              description: "A guest's key to their cart. Sent with a session right after signing in, it gives the " \
                           "guest's cart to the account when the account has none; carts are never merged"

    get 'Shows the cart with the live prices of its drugstore' do
      tags 'Cart'
      description 'Prices and stock are asked of the provider live and never stored: an item the drugstore has not ' \
                  'now stays in the cart as not available. A provider that does not answer gives the cart without ' \
                  'prices, not an error. What can no longer be sold is taken out and listed in `removed`; a cart ' \
                  'whose drugstore or provider went is gone.'
      produces 'application/json'

      response '200', 'the cart with live prices' do
        schema '$ref' => '#/components/schemas/cart_response'

        run_test! do
          body = response.parsed_body['cart']
          expect(body).to include(
            'token' => cart.token,
            'prices_available' => true,
            'total' => '162.50',
            'removed' => []
          )
        end
      end

      response '200', 'the provider did not answer: the items without prices' do
        schema '$ref' => '#/components/schemas/cart_response'

        before do
          stub_request(
            :post,
            pharmapoint_url('order/get-drugstore-for-order-goods')
          ).with(query: hash_including({})).to_timeout
        end

        run_test! do
          expect(response.parsed_body['cart']).to include('prices_available' => false, 'total' => nil)
        end
      end

      response '200', "a signed-in user's cart, with no token in the answer" do
        schema '$ref' => '#/components/schemas/cart_response'

        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }
        let(:'X-Cart-Token') { nil }

        before { cart.update!(user_id: 42) }

        run_test! { expect(response.parsed_body['cart']).not_to have_key('token') }
      end

      response '404', 'cart_not_found: no cart, a token of no cart, or a cart whose drugstore or provider went' do
        schema '$ref' => '#/components/schemas/error'

        let(:'X-Cart-Token') { 'not-a-token' }

        run_test! { expect(error_code).to eq('cart_not_found') }
      end

      response '401', 'an expired or invalid token' do
        schema '$ref' => '#/components/schemas/error'

        let(:Authorization) { 'Bearer not-a-jwt' }

        run_test! { expect(error_code).to eq('unauthorized') }
      end
    end

    delete 'Clears the cart for good' do
      tags 'Cart'
      description 'Removes the cart with its items, so a cart can be started in another drugstore.'

      response '204', 'the cart is gone' do
        run_test! { expect(Order.exists?(cart.id)).to be(false) }
      end

      response '404', 'cart_not_found' do
        schema '$ref' => '#/components/schemas/error'

        let(:'X-Cart-Token') { 'not-a-token' }

        run_test! { expect(error_code).to eq('cart_not_found') }
      end
    end
  end
end
