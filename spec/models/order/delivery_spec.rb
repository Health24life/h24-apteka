# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order::Delivery do
  subject(:delivery) { build(:order_delivery, order: create(:order, :submitted)) }

  let(:order) { create(:order) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:order).inverse_of(:delivery) }

  it 'picks up by default' do
    expect(described_class.new.delivery_type_code).to eq('pick_up')
  end

  it 'knows the methods of the dictionary', :aggregate_failures do
    expect(described_class::TYPES).to eq(%w[pick_up ukr_post nova_poshta meest_express justin uklon ipost])
    expect(build(:order_delivery, order:, delivery_type_code: 'dhl')).not_to be_valid
  end

  it 'needs no address for a pick-up' do
    expect(build(:order_delivery, order:, address: nil)).to be_valid
  end

  describe 'delivery' do
    before { order.provider.update!(supports_delivery: true) }

    it 'takes an address with a street and a house' do
      expect(build(:order_delivery, :ukr_post, order:)).to be_valid
    end

    it 'takes an address with a post office instead of a street' do
      address = build(:order_delivery_address, street: nil, building: nil, post_office: '12')

      expect(build(:order_delivery, :ukr_post, order:, address:)).to be_valid
    end

    it 'needs an address', :aggregate_failures do
      without = build(:order_delivery, :ukr_post, order:, address: nil)

      expect(without).not_to be_valid
      expect(without.errors).to be_added(:address, :blank)
    end

    it 'refuses an invalid address' do
      address = build(:order_delivery_address, city: 'Kyiv', street: nil, building: nil)

      expect(build(:order_delivery, :ukr_post, order:, address:)).not_to be_valid
    end

    it 'saves the address together with the delivery', :aggregate_failures do
      saved = create(:order_delivery, :ukr_post, order:)

      expect(saved.reload.address).to have_attributes(city: 'Kyiv', street: 'Khreshchatyk', building: '1')
      expect { saved.destroy! }.to change(Order::DeliveryAddress, :count).by(-1)
    end
  end

  describe 'a provider without delivery' do
    before { order.provider.update!(supports_delivery: false) }

    it 'cannot get a new delivery', :aggregate_failures do
      refused = build(:order_delivery, :ukr_post, order:)

      expect(refused).not_to be_valid
      expect(refused.errors).to be_added(:delivery_type_code, :delivery_not_supported)
    end

    it 'still gets a pick-up' do
      expect(build(:order_delivery, order:)).to be_valid
    end

    it 'does not stop updating a delivery that already exists' do
      order.provider.update!(supports_delivery: true)
      saved = create(:order_delivery, :ukr_post, order:)
      order.provider.update!(supports_delivery: false)

      expect(saved.reload.address.update(city: 'Odesa')).to be(true)
    end
  end

  it 'words its refusal in the locale files', :aggregate_failures do
    order.provider.update!(supports_delivery: false)
    messages = build(:order_delivery, :ukr_post, order:).tap(&:validate).errors.full_messages

    expect(messages).not_to be_empty
    expect(messages.grep(/translation missing/i)).to be_empty
  end

  describe 'database level, bypassing validations' do
    let(:now) { Time.current }
    let(:row) { { order_id: order.id, delivery_type_code: 'pick_up', created_at: now, updated_at: now } }

    def store_row(attributes)
      described_class.insert_all!([ attributes ]) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'refuses a method outside the dictionary' do
      expect { store_row(row.merge(delivery_type_code: 'dhl')) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'refuses a second delivery of the order' do
      store_row(row)

      expect { store_row(row) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'goes with its order' do
      store_row(row)

      expect { order.delete }.to change(described_class, :count).by(-1)
    end
  end
end

# == Schema Information
#
# Table name: order_deliveries
#
#  id                 :bigint           not null, primary key
#  delivery_type_code :string           default("pick_up"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  order_id           :bigint           not null
#
# Indexes
#
#  index_order_deliveries_on_order_id  (order_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id) ON DELETE => cascade
#
# Check Constraints
#
#  order_deliveries_type_check  (delivery_type_code::text = ANY (ARRAY['pick_up'::character varying, 'ukr_post'::character varying, 'nova_poshta'::character varying, 'meest_express'::character varying, 'justin'::character varying, 'uklon'::character varying, 'ipost'::character varying]::text[]))
#
