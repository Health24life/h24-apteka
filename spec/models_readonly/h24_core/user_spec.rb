# frozen_string_literal: true

require 'rails_helper'

RSpec.describe H24Core::User do
  describe '#contact_email' do
    it 'returns a real e-mail address' do
      expect(build(:h24_core_user, email: 'anna@example.com').contact_email).to eq('anna@example.com')
    end

    it 'hides the placeholder address given to phone-only sign-ups' do
      expect(build(:h24_core_user, email: 'change@me-380501234567.com').contact_email).to be_nil
    end

    it 'returns nil when the e-mail is missing' do
      expect(build(:h24_core_user, email: nil).contact_email).to be_nil
    end

    it 'returns nil when the e-mail is empty' do
      expect(build(:h24_core_user, email: '').contact_email).to be_nil
    end
  end

  describe '#phone_digits' do
    it 'drops the leading plus' do
      expect(build(:h24_core_user, phone_number: '+380501234567').phone_digits).to eq('380501234567')
    end

    it 'is nil without a phone number' do
      expect(build(:h24_core_user, phone_number: nil).phone_digits).to be_nil
    end
  end

  it 'is connected to the core database, not the primary one' do
    expect(described_class.connection_db_config.name).to eq('h24_core')
  end

  it 'is persisted in the core database' do
    user = create(:h24_core_user)

    expect(described_class.find(user.id)).to eq(user)
  end

  describe 'orders' do
    it 'lists the orders of the user and finds the cart', :aggregate_failures do
      user = create(:h24_core_user)
      cart = create(:order, user_id: user.id)

      expect(user.orders).to contain_exactly(cart)
      expect(user.cart_order).to eq(cart)
      expect(cart.user).to eq(user)
    end

    it 'has no cart without an order' do
      expect(create(:h24_core_user).cart_order).to be_nil
    end
  end
end
