# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order::Payment do
  subject(:payment) { build(:order_payment) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:order).inverse_of(:payment) }

  it 'takes only the offline methods', :aggregate_failures do
    expect(described_class.payment_type_codes.values).to eq(%w[cash_in_store cash_on_delivery])
    described_class.payment_type_codes.each_value do |type|
 expect(build(:order_payment, payment_type_code: type)).to be_valid
    end
  end

  it 'refuses an online payment, an unknown one and none', :aggregate_failures do
    [ 'online', 'card', nil ].each do |type|
      expect(build(:order_payment, payment_type_code: type)).not_to be_valid
    end
  end

  describe 'database level, bypassing validations' do
    let(:order) { create(:order) }
    let(:now) { Time.current }
    let(:row) { { order_id: order.id, payment_type_code: 'cash_in_store', created_at: now, updated_at: now } }

    def store_row(attributes)
      described_class.insert_all!([ attributes ]) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'refuses a method outside the dictionary' do
      expect { store_row(row.merge(payment_type_code: 'online')) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'refuses a second payment of the order' do
      store_row(row)

      expect { store_row(row) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end

# == Schema Information
#
# Table name: order_payments
#
#  id                :bigint           not null, primary key
#  payment_type_code :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  order_id          :bigint           not null
#
# Indexes
#
#  index_order_payments_on_order_id  (order_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id) ON DELETE => cascade
#
# Check Constraints
#
#  order_payments_type_check  (payment_type_code::text = ANY (ARRAY['cash_in_store'::character varying, 'cash_on_delivery'::character varying]::text[]))
#
