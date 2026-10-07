# frozen_string_literal: true

FactoryBot.define do
  factory :order_payment, class: 'Order::Payment' do
    order
    payment_type_code { 'cash_in_store' }
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
