# frozen_string_literal: true

FactoryBot.define do
  factory :order_item, class: 'Order::Item' do
    order
    goods { association :catalog_goods, strategy: :create }
    quantity { 1 }

    transient do
      served { true }
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
#  id          :bigint           not null, primary key
#  price_cents :integer
#  quantity    :decimal(12, 4)   not null
#  total_cents :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  goods_id    :bigint
#  order_id    :bigint           not null
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
#  order_items_quantity_check  (quantity > 0::numeric)
#
