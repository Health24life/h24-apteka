# frozen_string_literal: true

# Offline only: paid in the pharmacy or when the order is received. There is no online payment yet.
class Order::Payment < ApplicationRecord
  self.table_name = 'order_payments'

  TYPES = %w[cash_in_store cash_on_delivery].freeze

  enum :payment_type_code, TYPES.index_with(&:itself), validate: true
  belongs_to :order, inverse_of: :payment
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
