# frozen_string_literal: true

FactoryBot.define do
  factory :order_delivery, class: 'Order::Delivery' do
    order
    delivery_type_code { 'pick_up' }

    trait :ukr_post do
      delivery_type_code { 'ukr_post' }
      address { association :order_delivery_address, delivery: instance, strategy: :build }
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
