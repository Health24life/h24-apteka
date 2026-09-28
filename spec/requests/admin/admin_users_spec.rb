# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::AdminUsers' do
  let(:admin) { create(:admin_user) }

  before { sign_in admin }

  it 'lists admin users', :aggregate_failures do
    other = create(:admin_user)

    get admin_admin_users_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(other.email)
  end

  it 'creates an admin user' do
    expect do
      post admin_admin_users_path, params: {
        admin_user: { email: 'new@example.com', password: 'secret123', password_confirmation: 'secret123' }
      }
    end.to change(AdminUser, :count).by(1)
  end

  it 'updates another admin without touching the password' do
    other = create(:admin_user)
    params = { admin_user: { email: 'renamed@example.com', password: '', password_confirmation: '', is_active: '0' } }

    expect { patch admin_admin_user_path(other), params: }
      .to change { other.reload.slice(:email, :is_active, :encrypted_password).values }
      .to([ 'renamed@example.com', false, other.encrypted_password ])
  end

  it 'ignores an attempt to deactivate your own account' do
    patch admin_admin_user_path(admin), params: { admin_user: { password: '', is_active: '0' } }

    expect(admin.reload).to be_is_active
  end

  it 'signs a deactivated admin out on the next request' do
    admin.update!(is_active: false)

    get admin_root_path

    expect(response).to redirect_to(new_admin_user_session_path)
  end
end
