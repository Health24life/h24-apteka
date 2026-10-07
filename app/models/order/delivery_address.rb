# frozen_string_literal: true

# Where a delivery goes: a city plus either a street with a house or the number of a post office.
class Order::DeliveryAddress < ApplicationRecord
  POSTAL_CODE_FORMAT = /\A\d{5}\z/

  belongs_to :delivery, class_name: 'Order::Delivery', inverse_of: :address

  validates :city, presence: true
  validates :postal_code, format: { with: POSTAL_CODE_FORMAT }, allow_blank: true
  validates :street, :building, presence: true, if: -> { post_office.blank? }
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
