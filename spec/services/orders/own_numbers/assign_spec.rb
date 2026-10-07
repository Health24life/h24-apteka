# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::OwnNumbers::Assign do
  let(:cart) { create(:order) }

  it 'gives the order a number of ten letters or digits', :aggregate_failures do
    described_class.call(cart)

    expect(cart.own_number).to match(/\A[A-Z0-9]{10}\z/)
    expect(cart).to be_changed
  end

  it 'only assigns the number and does not save it' do
    described_class.call(cart)

    expect(cart.reload.own_number).to be_nil
  end

  it 'returns the order' do
    expect(described_class.call(cart)).to equal(cart)
  end

  it 'keeps the number the order already has', :aggregate_failures do
    sent = create(:order, :submission_failed)

    expect { described_class.call(sent) }.not_to change(sent, :own_number)
    expect { described_class.call(sent) }.not_to change(sent, :changed?)
  end

  it 'replaces a blank number' do
    cart.own_number = '  '

    expect(described_class.call(cart).own_number).to match(/\A[A-Z0-9]{10}\z/)
  end

  it 'gives different orders different numbers' do
    numbers = create_list(:order, 3).map { described_class.call(it).own_number }

    expect(numbers.uniq.size).to eq(3)
  end

  it 'takes another candidate while the first is taken' do
    allow(Order).to receive(:exists?).and_return(true, true, false)

    described_class.call(cart)

    expect(Order).to have_received(:exists?).exactly(3).times
  end

  it 'is saved by the caller together with the new state' do
    cart.assign_attributes(state: 'submitted', personal_data_consent_at: Time.current, customer_first_name: 'Anna',
                           customer_phone_number: '380501234567', provider_drugstore_external_id: '1',
                           provider_order_number: 'PP1', delivery: build(:order_delivery, order: cart),
                           payment: build(:order_payment, order: cart))

    expect(described_class.call(cart).save).to be(true)
  end
end
