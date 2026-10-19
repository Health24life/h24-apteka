# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Booking the cart', :partner_calls do
  let(:Authorization) { nil }
  let(:order_token) { cart.token }
  let(:body) { booking_body(cart, price: '162.50').merge('cf-turnstile-response' => 'mocked') }

  before do
    use_pharmapoint_config
    use_booking_config(drugstore_ids: [ cart.drugstore_id ])
    stub_drugstore_offers
    stub_request(
      :post,
      pharmapoint_url('order/store-pick-up-order')
    ).to_return(pharmapoint_answer('partner_order_created'))
  end

  def provider = @provider ||= create(:provider, code: 'pharmapoint')

  def cart
    @cart ||= begin
      drugstore = create(:catalog_drugstore)
      goods = create(:catalog_goods)
      [ drugstore, goods ].each { ProviderLinking.link(provider, it) }
      guest_cart(provider:, drugstore:, goods:)
    end
  end

  def error_code = response.parsed_body.dig('error', 'code')

  path '/api/v1/orders/{order_token}/booking' do
    parameter name: :order_token, in: :path, required: true, schema: { type: :string }, description: 'Token of the cart'
    parameter name: :Authorization,
              in: :header,
              required: false,
              schema: { type: :string },
              description: 'Bearer token of a signed-in user; the cart of an account books only with it'

    post 'Books the cart for pick-up' do
      tags 'Booking'
      description 'Sends the cart to the drugstore as a pick-up paid there, with no prepayment. The goods must be ' \
                  'those of the cart, with the prices the user saw: prices and stock are confirmed live first, a ' \
                  'higher price or a missing item stops the booking for a new consent, a lower price is taken. The ' \
                  'consent to the processing of personal data is checked by the server. The same call tries again ' \
                  'a booking whose sending failed, after looking for it at the partner so no second order is made. ' \
                  'The order keeps the token of the cart, which is also the link it is shared by; the client data ' \
                  "comes back only to the signed-in user of the order's account."
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: { '$ref' => '#/components/schemas/booking_request' }

      response '201', 'the booking is with the drugstore' do
        schema '$ref' => '#/components/schemas/order_response'

        run_test! do
          expect(response.parsed_body['order']).to include(
            'token' => cart.token,
            'state' => 'submitted',
            'customer_number' => '123456',
            'total' => '162.50'
          )
        end
      end

      response '201', "a signed-in user's booking comes back with the client's data" do
        schema '$ref' => '#/components/schemas/order_response'

        let(:Authorization) { "Bearer #{generate_jwt_token(nameid: 42)}" }

        before { cart.update!(user_id: 42) }

        run_test! do
          expect(response.parsed_body.dig('order', 'customer'))
            .to include('first_name' => 'Олена', 'phone_number' => '380671234567')
        end
      end

      response '201', 'the share of the cart in the request limit is used up, the booking still goes' do
        schema '$ref' => '#/components/schemas/order_response'

        before { use_pharmapoint_config(cart: { rate_limit_per_minute: 0 }) }

        run_test! { expect(response.parsed_body.dig('order', 'state')).to eq('submitted') }
      end

      response '403', 'turnstile_failed: the check of Cloudflare Turnstile did not pass' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { booking_body(cart).merge('cf-turnstile-response' => 'bot') }

        run_test! { expect(error_code).to eq('turnstile_failed') }
      end

      response '404', "cart_not_found: no such cart, or an account's cart without its session" do
        schema '$ref' => '#/components/schemas/error'

        let(:order_token) { 'not-a-token' }

        run_test! { expect(error_code).to eq('cart_not_found') }
      end

      response '409', 'booking_prices_changed: a price rose or an item is missing; details give the new items' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { booking_body(cart, price: '150').merge('cf-turnstile-response' => 'mocked') }

        run_test! do
          expect(response.parsed_body['error']).to include(
            'code' => 'booking_prices_changed',
            'details' => { 'items' => [ include('price' => '162.50', 'available' => true) ] }
          )
        end
      end

      response '409', 'cart_changed: the goods sent are not those of the cart' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) do
 booking_body(cart).merge(
   'goods' => [ { 'goods_id' => 0, 'quantity' => 1, 'price' => '1' } ],
   'cf-turnstile-response' => 'mocked'
 )
        end

        run_test! { expect(error_code).to eq('cart_changed') }
      end

      response '422', 'personal_data_consent_required: no consent to the processing of personal data' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { booking_body(cart, consent: false).merge('cf-turnstile-response' => 'mocked') }

        run_test! { expect(error_code).to eq('personal_data_consent_required') }
      end

      response '422', 'invalid_customer: a name, a phone or an email that cannot be taken; details name the field' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) do
 booking_body(cart, customer: { 'phone_number' => '067' }).merge('cf-turnstile-response' => 'mocked')
        end

        run_test! do
          expect(response.parsed_body['error']).to include(
            'code' => 'invalid_customer',
            'details' => { 'field' => 'phone_number' }
          )
        end
      end

      response '422', 'booking_not_allowed_in_drugstore: booking is not open in this drugstore yet' do
        schema '$ref' => '#/components/schemas/error'

        before { use_booking_config(drugstore_ids: []) }

        run_test! { expect(error_code).to eq('booking_not_allowed_in_drugstore') }
      end

      response '502', 'booking_submission_failed: the partner did not take the order; the same call tries again' do
        schema '$ref' => '#/components/schemas/error'

        before { stub_request(:post, pharmapoint_url('order/store-pick-up-order')).to_timeout }

        run_test! { expect([ error_code, cart.reload.state ]).to eq(%w[booking_submission_failed submission_failed]) }
      end

      response '503',
               'booking_check_unavailable, or booking_check_busy with Retry-After: prices could not be confirmed' do
        schema '$ref' => '#/components/schemas/error'

        before do
          stub_request(
            :post,
            pharmapoint_url('order/get-drugstore-for-order-goods')
          ).with(query: hash_including({})).to_timeout
        end

        run_test! { expect([ error_code, cart.reload.state ]).to eq(%w[booking_check_unavailable cart]) }
      end
    end
  end
end
