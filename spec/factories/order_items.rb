# frozen_string_literal: true

FactoryBot.define do
  factory :order_item, class: 'Order::Item' do
    order
    goods { association :catalog_goods, strategy: :create }
    quantity { 1 }

    transient do
      served { true }
    end

    # An item of a sent order is a snapshot, so it carries its own name and the provider's ID of the product.
    after(:build) do |item|
      next if item.order.cart?

      item.name ||= 'Medicine'
      item.provider_goods_external_id ||= SecureRandom.uuid
    end

    after(:build) do |item, evaluator|
      ProviderLinking.link(item.order.provider, item.goods) if evaluator.served && item.goods
    end
  end
end

# == Schema Information
#
# Table name: order_items
#
#  id                         :bigint           not null, primary key
#  image_paths                :jsonb            not null
#  name                       :string
#  price                      :decimal(12, 2)
#  producer                   :string
#  quantity                   :decimal(12, 4)   not null
#  release_form               :string
#  total                      :decimal(12, 2)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  goods_id                   :bigint
#  order_id                   :bigint           not null
#  provider_goods_external_id :string
#
# Indexes
#
#  index_order_items_on_order_id  (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (goods_id => catalog_goods.id)
#  fk_rails_...  (order_id => orders.id) ON DELETE => cascade
#
# Check Constraints
#
#  order_items_amounts_check      (price >= 0::numeric AND total >= 0::numeric)
#  order_items_image_paths_check  (jsonb_typeof(image_paths) = 'array'::text)
#  order_items_quantity_check     (quantity > 0::numeric)
#
