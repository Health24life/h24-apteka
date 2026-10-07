# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Masker do
  subject(:masker) { described_class.new(config: pharmapoint_config) }

  describe '#headers' do
    it 'lowercases the names and hides the key and the phone of a client', :aggregate_failures do
      result = masker.headers('API-Key' => 'secret-key', 'Customer-Phone' => '380501112233',
                              'Accept' => 'application/json')

      expect(result).to eq('api-key' => '[masked]', 'customer-phone' => '[masked]', 'accept' => 'application/json')
    end
  end

  describe '#body' do
    it 'hides the phone of a client at any depth and leaves the rest as it is' do
      body = { 'customer_phone' => '380501112233', 'goods' => [ { 'id' => 1, 'customer_phone' => '1' } ], 'total' => 5 }

      expect(masker.body(body)).to eq('customer_phone' => '[masked]', 'total' => 5,
                                      'goods' => [ { 'id' => 1, 'customer_phone' => '[masked]' } ])
    end

    it 'removes what jsonb refuses: NUL characters and invalid UTF-8', :aggregate_failures do
      expect(masker.body("a\u0000b")).to eq('ab')
      expect(masker.body("caf\xE9".b)).to eq('caf�')
    end
  end

  describe '#text' do
    it 'cuts the key out of a message' do
      expect(masker.text('request with secret-key failed')).to eq('request with [masked] failed')
    end
  end
end
