# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidekiq dashboard' do
  it 'redirects guests to the admin login' do
    get '/admin/sidekiq'

    expect(response).to redirect_to('/admin/login')
  end

  it 'links the queues and cron pages from the admin menu', :aggregate_failures do
    sign_in create(:admin_user)

    get admin_root_path

    expect(response.body).to include('href="/admin/sidekiq"')
    expect(response.body).to include('href="/admin/sidekiq/cron"')
  end
end
