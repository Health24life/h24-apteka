# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController do
  controller do
    def index
      render json: { user_id: current_user_id }
    end
  end

  it 'rejects a request without a session token' do
    get :index

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a request with an expired token' do
    request.headers['Authorization'] = "Bearer #{generate_jwt_token(nameid: 1, exp: 1.hour.ago.to_i)}"

    get :index

    expect(response.parsed_body).to eq('error' => 'expired')
  end

  it 'resolves the session from a valid bearer token' do
    request.headers['Authorization'] = "Bearer #{generate_jwt_token(nameid: 42)}"

    get :index

    expect(response.parsed_body).to eq('user_id' => 42)
  end
end
