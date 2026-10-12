# frozen_string_literal: true

# How the order is received. Anything but pick-up is a delivery and needs an address.
class Order::Delivery < ApplicationRecord
  self.table_name = 'order_deliveries'

  PICK_UP = 'pick_up'
  TYPES = [ PICK_UP, 'ukr_post', 'nova_poshta', 'meest_express', 'justin', 'uklon', 'ipost' ].freeze

  enum :delivery_type_code, TYPES.index_with(&:itself), validate: true, default: PICK_UP

  belongs_to :order, inverse_of: :delivery
  has_one :address, class_name: 'Order::DeliveryAddress', inverse_of: :delivery, dependent: :delete, autosave: true

  validates :address, presence: true, unless: :pick_up?
  # The provider may stop delivering later; a sent order stays, so only a new delivery is checked.
  validate :provider_supports_delivery, on: :create, unless: :pick_up?

  private

  def provider_supports_delivery
    provider = order&.provider
    errors.add(:delivery_type_code, :delivery_not_supported) if provider && !provider.supports_delivery?
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
