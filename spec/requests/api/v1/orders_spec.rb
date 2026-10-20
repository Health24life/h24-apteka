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

    get "Lists the bookings of the signed-in user's account" do
      tags 'Booking'
      description 'Newest first by the moment of booking, a page at a time, from what Health24 keeps of each ' \
                  "booking: the partner is not asked, and the statuses are those the poll kept. A guest's bookings " \
                  'have no history. `has_more` tells whether there is a next page. Open one booking by its `token`.'
      produces 'application/json'
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 1 }
      parameter name: :per_page,
                in: :query,
                required: false,
                schema: { type: :integer, minimum: 1 },
                description: 'Up to the configured maximum, 20 by default'

      let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }

      response '200', 'the bookings of the account, newest first' do
        schema '$ref' => '#/components/schemas/history_response'

        before do
          create(:order, :submitted, user_id: 42, personal_data_consent_at: 2.hours.ago)
          create(:order, :submitted, user_id: 42, own_number: 'NEWER00001', personal_data_consent_at: 1.hour.ago)
          create(:order, :submitted, user_id: 7)
        end

        run_test! do
          expect(response.parsed_body).to include(
            'orders' => [
              include('own_number' => 'NEWER00001', 'state' => 'submitted'),
              include('state' => 'submitted')
            ],
            'has_more' => false
          )
        end
      end

      response '401', 'unauthorized: no session — a guest has no history' do
        schema '$ref' => '#/components/schemas/error'

        let(:Authorization) { nil }

        run_test! { expect(error_code).to eq('unauthorized') }
      end

      response '422', 'invalid_page: a page below one or a page size above the maximum' do
        schema '$ref' => '#/components/schemas/error'

        let(:page) { 0 }

        run_test! { expect(error_code).to eq('invalid_page') }
      end
    end

    post 'Makes the cart with its first SKU' do
      tags 'Cart'
      description 'A cart is an order in the cart state, bound to the drugstore its first SKU is put in. The answer ' \
                  "gives `token`, the owner's key to the cart used in the path of every call on it. A signed-in " \
                  'user who has a cart already gets the SKU put in it. The SKU is checked live against what the ' \
                  'drugstore has; nothing is saved when the check refuses or cannot be made.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: { '$ref' => '#/components/schemas/cart_item_request' }

      let(:body) { { goods_id: goods.id, drugstore_id: drugstore.id, quantity: 2 } }

      response '201', 'the cart is made, with its token' do
        schema '$ref' => '#/components/schemas/cart_response'

        run_test! { expect(cart_body).to include('token' => Order.cart.sole.token, 'total' => '325.00') }
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

      response '200', "a booked cart by its token, which is also the link: the order without the client's data" do
        schema '$ref' => '#/components/schemas/order_response'

        let(:token) { create(:order, :submitted, provider:, provider_order_number: 'PB-35-PT-H5', user_id: 42).token }

        before do
          stub_request(:get, pharmapoint_url('order/PB-35-PT-H5')).to_return(pharmapoint_answer('partner_order'))
        end

        run_test! do
          order = response.parsed_body['order']
          expect([ order['status']['comment'], order.key?('customer') ]).to eq([ 'Передан в обработку', false ])
        end
      end

      response '200', "the signed-in user of the order's account: the order with the client's data" do
        schema '$ref' => '#/components/schemas/order_response'

        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }
        let(:token) do
          create(:order, :submitted, provider:, user_id: 42, status_synced_at: Time.current).token
        end

        run_test! { expect(response.parsed_body.dig('order', 'customer', 'first_name')).to eq('Anna') }
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

    delete 'Clears the cart, or cancels the booking it became' do
      tags 'Cart'
      description 'A cart is removed with its items, so a cart can be started in another drugstore (204). A ' \
                  'booking is cancelled at the drugstore and stays, with the status the partner gives after it ' \
                  '(200), or with the status from before when the partner could not be asked again (202). ' \
                  "Only the signed-in user of the booking's account can cancel it: the token is also the " \
                  'link the booking is shared by. Only a booking the drugstore took, with a status that is not ' \
                  'final, can be cancelled. The reason is optional and comes in the body.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body,
                in: :body,
                required: false,
                schema: { '$ref' => '#/components/schemas/cancellation_request' }

      let(:body) { {} }

      response '204', 'the cart is gone' do
        run_test! { expect(Order.exists?(cart.id)).to be(false) }
      end

      response '200', 'the booking is cancelled; its status read again from the partner' do
        schema '$ref' => '#/components/schemas/order_response'

        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }
        let(:token) { booked.token }
        let(:body) { { reason: 'Передумала' } }

        def booked
          @booked ||= create(:order, :submitted, provider:, user_id: 42, provider_order_number: 'PB-35-PT-H5')
        end

        before do
          stub_request(:post, pharmapoint_url('order/cancel')).to_return(status: 200, body: '')
          stub_request(:get, pharmapoint_url('order/PB-35-PT-H5'))
            .to_return(pharmapoint_answer(
                         nil,
                         body: {
                           data: {
                             order_number: 'PB-35-PT-H5',
                             status_name: 'canceled'
                           }
                         }.to_json
                       ))
        end

        run_test! { expect(response.parsed_body.dig('order', 'state')).to eq('submitted') }
      end

      response '202', 'cancelled, but the partner did not answer for the status: the one from before is shown' do
        schema '$ref' => '#/components/schemas/order_response'

        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }
        let(:token) do
          create(:order, :submitted, provider:, user_id: 42, provider_order_number: 'PB-35-PT-H5').token
        end

        before do
          stub_request(:post, pharmapoint_url('order/cancel')).to_return(status: 200, body: '')
          stub_request(:get, pharmapoint_url('order/PB-35-PT-H5')).to_timeout
        end

        run_test! { expect(response.parsed_body.dig('order', 'token')).to eq(token) }
      end

      response '403', "cancellation_needs_account: only the user of the booking's account can cancel it" do
        schema '$ref' => '#/components/schemas/error'

        let(:token) { create(:order, :submitted, provider:).token }

        run_test! { expect(error_code).to eq('cancellation_needs_account') }
      end

      response '409', 'order_not_cancellable, or cancellation_refused when the drugstore did not accept it' do
        schema '$ref' => '#/components/schemas/error'

        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }
        let(:token) { create(:order, :submitted, provider:, user_id: 42, status_name: 'canceled').token }

        run_test! { expect(error_code).to eq('order_not_cancellable') }
      end

      response '404', 'cart_not_found' do
        schema '$ref' => '#/components/schemas/error'

        let(:token) { 'not-a-token' }

        run_test! { expect(error_code).to eq('cart_not_found') }
      end
    end
  end
end
