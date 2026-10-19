# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'The items of the cart', :partner_calls do
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

  path '/api/v1/orders/{order_token}/items' do
    parameter name: :order_token, in: :path, required: true, schema: { type: :string }, description: 'Token of the cart'

    let(:order_token) { cart.token }

    post 'Puts a SKU in the cart' do
      tags 'Cart'
      description 'The SKU goes to the drugstore of the cart only, and one already in the cart adds to its item. It ' \
                  'is checked live against what the drugstore has; nothing is saved when the check refuses or ' \
                  'cannot be made.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, required: true, schema: { '$ref' => '#/components/schemas/cart_item_request' }

      let(:body) { { goods_id: goods.id, drugstore_id: drugstore.id, quantity: 2 } }

      response '200', 'the SKU went to the cart' do
        schema '$ref' => '#/components/schemas/cart_response'

        run_test! { expect(cart_body['items'].sole['quantity']).to eq(3) }
      end

      response '404', 'cart_not_found, goods_not_found' do
        schema '$ref' => '#/components/schemas/error'

        let(:order_token) { 'not-a-token' }

        run_test! { expect(error['code']).to eq('cart_not_found') }
      end

      response '409', 'cart_drugstore_mismatch: the cart is in another drugstore; clear it to start in this one' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { goods_id: goods.id, drugstore_id: linked(create(:catalog_drugstore)).id, quantity: 1 } }

        run_test! { expect(error['code']).to eq('cart_drugstore_mismatch') }
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
    end
  end

  path '/api/v1/orders/{order_token}/items/{id}' do
    parameter name: :order_token, in: :path, required: true, schema: { type: :string }, description: 'Token of the cart'
    parameter name: :id, in: :path, required: true, schema: { type: :integer }

    let(:order_token) { cart.token }
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
