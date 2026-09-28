# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidekiq dashboard' do
  let(:menu_links) do
    %w[/admin/sidekiq /admin/sidekiq/cron /admin/sidekiq/failures /admin/sidekiq/statuses].map { "href=\"#{it}\"" }
  end

  it 'redirects guests to the admin login' do
    get '/admin/sidekiq'

    expect(response).to redirect_to('/admin/login')
  end

  it 'links the Sidekiq pages from the admin menu' do
    sign_in create(:admin_user)

    get admin_root_path

    expect(response.body).to include(*menu_links)
  end
end
