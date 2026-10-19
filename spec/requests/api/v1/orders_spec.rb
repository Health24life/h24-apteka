# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'The cart', :partner_calls do
  let(:Authorization) { nil }

  before do
    use_pharmapoint_config
    stub_drugstore_offers
  end

  def provider = @provider ||= create(:provider, code: 'pharmapoint')

  def drugstore = @drugstore ||= linked(create(:catalog_drugstore))

  def goods = @goods ||= linked(create(:catalog_goods))

  def cart = @cart ||= guest_cart(provider:, drugstore:, goods:)

  def linked(record)
    ProviderLinking.link(provider, record)
    record
  end

  def error_code = response.parsed_body.dig('error', 'code')

  def cart_body = response.parsed_body['cart']

  def stub_unanswered
    stub_request(:post, pharmapoint_url('order/get-drugstore-for-order-goods'))
      .with(query: hash_including({}))
      .to_timeout
  end

  shared_context 'with the session of a user' do
    parameter name: :Authorization,
              in: :header,
              required: false,
              schema: { type: :string },
              description: 'Bearer token of a signed-in user; the cart of an account opens only with it'
  end

  path '/api/v1/orders' do
    include_context 'with the session of a user'

    post 'Makes the cart with its first SKU' do
      tags 'Cart'
      description 'A cart is an order in the cart state, bound to the drugstore its first SKU is put in. The answer ' \
                  "gives `token`, the owner's key to the cart used in the path of every call on it, and " \
                  '`share_token` for a link anyone can open to look. A signed-in user who has a cart already gets ' \
                  'the SKU put in it. The SKU is checked live against what the drugstore has; nothing is saved when ' \
                  'the check refuses or cannot be made.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: { '$ref' => '#/components/schemas/cart_item_request' }

      let(:body) { { goods_id: goods.id, drugstore_id: drugstore.id, quantity: 2 } }

      response '201', 'the cart is made, with its token and its share token' do
        schema '$ref' => '#/components/schemas/cart_response'

        run_test! do
          made = Order.cart.sole
          expect(cart_body).to include('token' => made.token, 'share_token' => made.share_token, 'total' => '325.00')
        end
      end

      response '200', 'a signed-in user had a cart: the SKU went to it' do
        schema '$ref' => '#/components/schemas/cart_response'

        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }

        before { cart.update!(user_id: 42) }

        run_test! { expect(cart_body).to include('token' => cart.token, 'items' => [ include('quantity' => 3) ]) }
      end

      response '404', 'goods_not_found or drugstore_not_found' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { goods_id: goods.id, drugstore_id: 0, quantity: 1 } }

        run_test! { expect(error_code).to eq('drugstore_not_found') }
      end

      response '422', 'quantity_exceeds_stock, goods_not_in_drugstore or invalid_quantity' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { goods_id: goods.id, drugstore_id: drugstore.id, quantity: 4 } }

        run_test! do
          expect(response.parsed_body['error'])
            .to include('code' => 'quantity_exceeds_stock', 'details' => { 'available_quantity' => 3 })
        end
      end

      response '503', 'cart_check_unavailable, or cart_check_busy with Retry-After: the stock could not be checked' do
        schema '$ref' => '#/components/schemas/error'

        before { stub_unanswered }

        run_test! { expect([ error_code, Order.count ]).to eq([ 'cart_check_unavailable', 0 ]) }
      end
    end
  end

  path '/api/v1/orders/current' do
    include_context 'with the session of a user'

    get "Shows the signed-in user's cart" do
      tags 'Cart'
      description "The way a signed-in user learns the token of the account's cart."
      produces 'application/json'

      let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }

      response '200', "the account's cart with live prices" do
        schema '$ref' => '#/components/schemas/cart_response'

        before { cart.update!(user_id: 42) }

        run_test! { expect(cart_body['token']).to eq(cart.token) }
      end

      response '404', 'cart_not_found: the account has no cart, or there is no session' do
        schema '$ref' => '#/components/schemas/error'

        run_test! { expect(error_code).to eq('cart_not_found') }
      end
    end
  end

  path '/api/v1/orders/{token}' do
    include_context 'with the session of a user'
    parameter name: :token, in: :path, required: true, schema: { type: :string }, description: 'Token of the cart'

    let(:token) { cart.token }

    get 'Shows the cart with the live prices of its drugstore' do
      tags 'Cart'
      description 'Prices and stock are asked of the provider live and never stored: an item the drugstore has not ' \
                  'now stays in the cart as not available. A provider that does not answer gives the cart without ' \
                  'prices, not an error. What can no longer be sold is taken out and listed in `removed`; a cart ' \
                  "whose drugstore or provider went is gone. A signed-in user who opens a guest's cart takes it to " \
                  'the account when the account has none; carts are never merged.'
      produces 'application/json'

      response '200', 'the cart with live prices' do
        schema '$ref' => '#/components/schemas/cart_response'

        run_test! { expect(cart_body).to include('prices_available' => true, 'total' => '162.50', 'removed' => []) }
      end

      response '200', 'the provider did not answer: the items without prices' do
        schema '$ref' => '#/components/schemas/cart_response'

        before { stub_unanswered }

        run_test! { expect(cart_body).to include('prices_available' => false, 'total' => nil) }
      end

      response '404', "cart_not_found: no such cart, an account's cart without its session, or a cart that went" do
        schema '$ref' => '#/components/schemas/error'

        before { cart.update!(user_id: 42) }

        run_test! { expect(error_code).to eq('cart_not_found') }
      end

      response '401', 'an expired or invalid session' do
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

        let(:token) { 'not-a-token' }

        run_test! { expect(error_code).to eq('cart_not_found') }
      end
    end
  end
end
