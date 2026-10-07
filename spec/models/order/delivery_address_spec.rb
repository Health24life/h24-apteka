# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order::DeliveryAddress do
  subject(:address) { build(:order_delivery_address) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:delivery).inverse_of(:address) }

  it 'takes a post office instead of a street and a house' do
    expect(build(:order_delivery_address, street: nil, building: nil, post_office: '12')).to be_valid
  end

  it 'refuses the city alone' do
    expect(build(:order_delivery_address, street: nil, building: nil)).not_to be_valid
  end

  it 'refuses a street without a house' do
    expect(build(:order_delivery_address, building: nil)).not_to be_valid
  end

  it 'refuses a missing city' do
    expect(build(:order_delivery_address, city: nil)).not_to be_valid
  end

  it 'takes a postal code of five digits only, or none', :aggregate_failures do
    [ '01001', nil ].each { |code| expect(build(:order_delivery_address, postal_code: code)).to be_valid }
    %w[0100 010011 0100a].each { |code| expect(build(:order_delivery_address, postal_code: code)).not_to be_valid }
  end

  describe 'database level, bypassing validations' do
    let(:delivery) { create(:order_delivery) }
    let(:now) { Time.current }
    let(:row) do
      { delivery_id: delivery.id, city: 'Kyiv', street: 'Main', building: '1', created_at: now, updated_at: now }
    end

    def store_row(attributes)
      described_class.insert_all!([ attributes ]) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'accepts a complete address' do
      expect { store_row(row) }.not_to raise_error
    end

    it 'refuses a blank city', :aggregate_failures do
      [ nil, '', '  ' ].each { |city| expect { store_row(row.merge(city:)) }.to raise_error(ActiveRecord::StatementInvalid) }
    end

    it 'refuses the city alone and a street without a house', :aggregate_failures do
      [ { street: nil, building: nil }, { building: ' ' } ].each do |place|
        expect { store_row(row.merge(place)) }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    it 'refuses a malformed postal code' do
      expect { store_row(row.merge(postal_code: '123')) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'refuses a second address of the delivery' do
      store_row(row)

      expect { store_row(row) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end

# == Schema Information
#
# Table name: order_delivery_addresses
#
#  id          :bigint           not null, primary key
#  building    :string
#  city        :string           not null
#  post_office :string
#  postal_code :string
#  street      :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  delivery_id :bigint           not null
#
# Indexes
#
#  index_order_delivery_addresses_on_delivery_id  (delivery_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (delivery_id => order_deliveries.id) ON DELETE => cascade
#
# Check Constraints
#
#  order_delivery_addresses_city_check         (COALESCE(btrim(city::text), ''::text) <> ''::text)
#  order_delivery_addresses_place_check        (COALESCE(btrim(post_office::text), ''::text) <> ''::text OR COALESCE(btrim(street::text), ''::text) <> ''::text AND COALESCE(btrim(building::text), ''::text) <> ''::text)
#  order_delivery_addresses_postal_code_check  (postal_code IS NULL OR postal_code::text ~ '^[0-9]{5}$'::text)
#
