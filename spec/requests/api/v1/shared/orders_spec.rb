# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'A cart opened by its shared link', :partner_calls do
  let(:share_token) { cart.share_token }

  before do
    use_pharmapoint_config
    stub_drugstore_offers
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

  path '/api/v1/shared/orders/{share_token}' do
    parameter name: :share_token, in: :path, required: true, schema: { type: :string }

    get 'Shows a cart by its shared link' do
      tags 'Cart'
      description 'Anyone with the link sees the drugstore, the items and their live prices, and can change ' \
                  "nothing: the owner's token is not given."
      produces 'application/json'

      response '200', 'the cart, without the token of its owner' do
        schema '$ref' => '#/components/schemas/cart_response'

        run_test! do
          expect(response.parsed_body['cart']).to include('share_token' => cart.share_token, 'total' => '162.50')
            .and(satisfy { !it.key?('token') })
        end
      end

      response '404', 'cart_not_found: no cart has this link' do
        schema '$ref' => '#/components/schemas/error'

        let(:share_token) { 'not-a-token' }

        run_test! { expect(response.parsed_body.dig('error', 'code')).to eq('cart_not_found') }
      end
    end
  end
end
