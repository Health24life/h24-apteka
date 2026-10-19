# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'The items of the cart', :partner_calls do
  let(:'X-Cart-Token') { nil }

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

  def error = response.parsed_body['error']

  def cart_body = response.parsed_body['cart']

  shared_context 'with the key of the cart' do
    parameter name: :'X-Cart-Token',
              in: :header,
              required: false,
              schema: { type: :string },
              description: "A guest's key to their cart; without a cart, the first item makes one and its token " \
                           'comes back. A signed-in user is known by the Authorization header'
  end

  path '/api/v1/cart/items' do
    include_context 'with the key of the cart'

    post 'Puts a SKU in the cart' do
      tags 'Cart'
      description 'The first SKU makes the cart, bound to the drugstore it is put in; later ones go to that ' \
                  'drugstore only, and one already in the cart adds to its item. Each is checked live against what ' \
                  'the drugstore has; nothing is saved when the check refuses or cannot be made.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: { '$ref' => '#/components/schemas/cart_item_request' }

      let(:body) { { goods_id: goods.id, drugstore_id: drugstore.id, quantity: 2 } }

      response '201', 'the first SKU made the cart; a guest gets its token' do
        schema '$ref' => '#/components/schemas/cart_response'

        run_test! do
          expect(cart_body).to include(
            'token' => Order.cart.sole.token,
            'total' => '325.00',
            'items' => [ include('quantity' => 2, 'available' => true, 'price' => '162.50') ]
          )
        end
      end

      response '200', 'the SKU went to the cart that was there' do
        schema '$ref' => '#/components/schemas/cart_response'

        let(:'X-Cart-Token') { cart.token }

        run_test! { expect(cart_body['items'].sole['quantity']).to eq(3) }
      end

      response '404', 'goods_not_found or drugstore_not_found' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { goods_id: goods.id, drugstore_id: 0, quantity: 1 } }

        run_test! { expect(error['code']).to eq('drugstore_not_found') }
      end

      response '409', 'cart_drugstore_mismatch: the cart is in another drugstore; clear it to start in this one' do
        schema '$ref' => '#/components/schemas/error'

        let(:'X-Cart-Token') { cart.token }
        let(:body) { { goods_id: goods.id, drugstore_id: linked(create(:catalog_drugstore)).id, quantity: 1 } }

        run_test! { expect(error['code']).to eq('cart_drugstore_mismatch') }
      end

      response '422', 'quantity_exceeds_stock: the drugstore has fewer packs, given in details' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { goods_id: goods.id, drugstore_id: drugstore.id, quantity: 4 } }

        run_test! do
          expect(error).to include('code' => 'quantity_exceeds_stock', 'details' => { 'available_quantity' => 3 })
        end
      end

      response '422', 'goods_not_in_drugstore: the drugstore does not have the SKU' do
        schema '$ref' => '#/components/schemas/error'

        before { stub_drugstore_offers(fulfilled: false) }

        run_test! { expect(error['code']).to eq('goods_not_in_drugstore') }
      end

      response '422', 'invalid_quantity: not a whole number of packs from 1' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { goods_id: goods.id, drugstore_id: drugstore.id, quantity: 1.5 } }

        run_test! { expect(error['code']).to eq('invalid_quantity') }
      end

      response '503', 'cart_check_unavailable, or cart_check_busy with Retry-After: the stock could not be checked' do
        schema '$ref' => '#/components/schemas/error'

        before do
          stub_request(:post, pharmapoint_url('order/get-drugstore-for-order-goods'))
            .with(query: hash_including({}))
            .to_timeout
        end

        run_test! { expect([ error['code'], Order.count ]).to eq([ 'cart_check_unavailable', 0 ]) }
      end
    end
  end

  path '/api/v1/cart/items/{id}' do
    include_context 'with the key of the cart'
    parameter name: :id, in: :path, required: true, schema: { type: :integer }

    let(:'X-Cart-Token') { cart.token }
    let(:id) { cart.items.sole.id }

    patch 'Sets the quantity of an item' do
      tags 'Cart'
      description 'Checked live against what the drugstore has, as when a SKU is put in.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body,
                in: :body,
                required: true,
                schema: { '$ref' => '#/components/schemas/cart_quantity_request' }

      let(:body) { { quantity: 3 } }

      response '200', 'the cart with the new quantity' do
        schema '$ref' => '#/components/schemas/cart_response'

        run_test! { expect(cart_body['items'].sole).to include('quantity' => 3, 'total' => '487.50') }
      end

      response '404', 'cart_item_not_found: no such item in the cart' do
        schema '$ref' => '#/components/schemas/error'

        let(:id) { 0 }

        run_test! { expect(error['code']).to eq('cart_item_not_found') }
      end
    end

    delete 'Takes an item out of the cart' do
      tags 'Cart'
      description 'The cart goes with its last item; read the cart again for the rest.'

      response '204', 'the item is out' do
        run_test! { expect(Order.exists?(cart.id)).to be(false) }
      end

      response '404', 'cart_item_not_found' do
        schema '$ref' => '#/components/schemas/error'

        let(:id) { 0 }

        run_test! { expect(error['code']).to eq('cart_item_not_found') }
      end
    end
  end
end
