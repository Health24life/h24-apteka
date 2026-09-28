# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminUser do
  describe '#active_for_authentication?' do
    it 'allows an active admin to sign in' do
      expect(build(:admin_user)).to be_active_for_authentication
    end

    it 'refuses a deactivated admin' do
      expect(build(:admin_user, :inactive)).not_to be_active_for_authentication
    end
  end

  describe '.ransackable_attributes' do
    it 'never exposes the password hash to filters', :aggregate_failures do
      attributes = described_class.ransackable_attributes

      expect(attributes).to include('email')
      expect(attributes).not_to include('encrypted_password')
    end
  end
end
