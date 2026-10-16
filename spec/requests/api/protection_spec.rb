# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API protection' do
  describe 'CORS' do
    around do |example|
      origins = Rails.application.config.x.cors_origins
      Rails.application.config.x.cors_origins = [ 'https://h24.ua' ]
      example.run
    ensure
      Rails.application.config.x.cors_origins = origins
    end

    def preflight(origin)
      options '/api/v1/anything',
              headers: {
                'Origin' => origin,
                'Access-Control-Request-Method' => 'POST',
                'Access-Control-Request-Headers' => 'Authorization, Content-Type'
              }
    end

    it 'lets an allowed origin in without credentials', :aggregate_failures do
      preflight('https://h24.ua')

      expect(response.headers['Access-Control-Allow-Origin']).to eq('https://h24.ua')
      expect(response.headers['Access-Control-Allow-Credentials']).to be_nil
    end

    it 'gives no CORS headers to another origin' do
      preflight('https://evil.example')

      expect(response.headers['Access-Control-Allow-Origin']).to be_nil
    end

    it 'leaves paths outside the API without CORS headers' do
      options '/up', headers: { 'Origin' => 'https://h24.ua', 'Access-Control-Request-Method' => 'GET' }

      expect(response.headers['Access-Control-Allow-Origin']).to be_nil
    end
  end

  describe 'throttling' do
    let(:limit) { 2 }

    around do |example|
      store = Rack::Attack.cache.store
      settings = Rails.application.config.x.api_throttle.dup
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
      Rails.application.config.x.api_throttle.limit = limit
      example.run
    ensure
      Rack::Attack.cache.store = store
      Rails.application.config.x.api_throttle = settings
    end

    it 'refuses a client over the limit with the error format and a retry time', :aggregate_failures do
      limit.times { get '/api/v1/anything' }

      get '/api/v1/anything'

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig('error', 'code')).to eq('too_many_requests')
      expect(Integer(response.headers['Retry-After'])).to be_positive
    end

    it 'counts each client address apart' do
      limit.times { get '/api/v1/anything' }

      get '/api/v1/anything', env: { 'REMOTE_ADDR' => '203.0.113.7' }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it 'does not throttle paths outside the API' do
      (limit + 1).times { get '/up' }

      expect(response).to have_http_status(:ok)
    end
  end
end
