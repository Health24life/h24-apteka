# frozen_string_literal: true

FactoryBot.define do
  factory :order_delivery_address, class: 'Order::DeliveryAddress' do
    delivery { association :order_delivery, strategy: :build }
    city { 'Kyiv' }
    street { 'Khreshchatyk' }
    building { '1' }
    postal_code { '01001' }
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
