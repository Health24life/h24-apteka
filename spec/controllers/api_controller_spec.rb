# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiController do
  controller do
    def index
      render json: { user_id: current_user_id }
    end
  end

  it 'serves a request without a token as a guest', :aggregate_failures do
    get :index

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('user_id' => nil)
  end

  it 'resolves the session from a valid bearer token' do
    request.headers['Authorization'] = "Bearer #{generate_jwt_token(nameid: 42)}"

    get :index

    expect(response.parsed_body).to eq('user_id' => 42)
  end

  it 'refuses an expired token with the error code and a Ukrainian message', :aggregate_failures do
    request.headers['Authorization'] = "Bearer #{generate_jwt_token(nameid: 1, exp: 1.hour.ago.to_i)}"

    get :index

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq(
      'error' => { 'code' => 'unauthorized', 'message' => 'Сесія недійсна або завершилася. Увійдіть знову.' }
    )
  end

  it 'refuses a malformed token' do
    request.headers['Authorization'] = 'Bearer not-a-jwt'

    get :index

    expect(response).to have_http_status(:unauthorized)
  end

  it 'refuses a token signed with another secret' do
    request.headers['Authorization'] = "Bearer #{JWT.encode({ nameid: 1, exp: 5.minutes.from_now.to_i }, 'other')}"

    get :index

    expect(response).to have_http_status(:unauthorized)
  end

  it 'ignores a session cookie and serves the request as a guest' do
    request.cookies[H24Auth::SessionContext::AUTHORIZATION_COOKIE_KEY] = generate_jwt_token(nameid: 42)

    get :index

    expect(response.parsed_body).to eq('user_id' => nil)
  end
end
