# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Dashboard' do
  it 'redirects guests to the login page' do
    get admin_root_path

    expect(response).to redirect_to(new_admin_user_session_path)
  end

  it 'renders the dashboard for a signed-in admin' do
    sign_in create(:admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
  end

  it 'wires Tom Select into the admin importmap' do
    sign_in create(:admin_user)

    get admin_root_path

    expect(response.body).to include('active_admin_core', 'tom-select', 'activeadmin-tom_select')
  end
end
