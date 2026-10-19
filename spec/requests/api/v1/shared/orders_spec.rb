# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'A booking opened by its shared link', :partner_calls do
  let(:order) do
    create(:order, :submitted, provider: create(:provider, code: 'pharmapoint'), status_synced_at: Time.current)
  end
  let(:share_token) { order.share_token }

  before { use_pharmapoint_config }

  path '/api/v1/shared/orders/{share_token}' do
    parameter name: :share_token, in: :path, required: true, schema: { type: :string }

    get 'Shows a booking by its shared link' do
      tags 'Booking'
      description 'For someone else to pick the booking up without signing in: the numbers, the drugstore, the ' \
                  "items and the partner's status. No client's data and no owner's token; nothing can be changed. " \
                  'A cart does not open by its link.'
      produces 'application/json'

      response '200', "the booking, without the client's data or the owner's token" do
        schema '$ref' => '#/components/schemas/order_response'

        run_test! do
          keys = response.parsed_body['order'].keys & %w[own_number drugstore items customer token]
          expect(keys).to match_array(%w[own_number drugstore items])
        end
      end

      response '404', 'order_not_found: no booking has this link, or it is the link of a cart' do
        schema '$ref' => '#/components/schemas/error'

        let(:share_token) { create(:order).share_token }

        run_test! { expect(response.parsed_body.dig('error', 'code')).to eq('order_not_found') }
      end
    end
  end
end
