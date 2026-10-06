# frozen_string_literal: true

class Order::Item < ApplicationRecord
  # Mirrors decimal(12,4): below the minimum the column rounds down to zero, from the maximum it does not fit.
  MIN_QUANTITY = BigDecimal('0.0001')
  MAX_QUANTITY = BigDecimal(10**8)

  belongs_to :order, inverse_of: :items, touch: true
  belongs_to :goods, class_name: 'Catalog::Goods', optional: true, inverse_of: :order_items

  # The provider of an item is the provider of its cart; the validators below read it from here.
  delegate :provider, to: :order, allow_nil: true

  validates :goods, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: MIN_QUANTITY, less_than: MAX_QUANTITY }
  # Price and availability are always fetched live, so a cart never stores them.
  validates :price, :total, absence: true
  validate :goods_not_repeated
  validates :goods, served_by_provider: true, not_hidden: { via: :goods_group }, on: :create
  # A disabled provider may come back, so items that already exist stay; no new ones are added meanwhile.
  validates :provider, enabled: true, on: :create

  after_destroy :destroy_empty_cart

  private

  # An empty cart is never kept: removing its last item removes the order as well. Items that go away together with
  # their cart must not try to destroy it a second time.
  def destroy_empty_cart
    return if destroyed_by_association

    order.destroy! if order.cart? && !order.items.exists?
  end

  # Checked among the items of the cart in memory: a cart that is saved for the first time has no order_id yet,
  # so a database uniqueness check would let the same SKU in twice.
  def goods_not_repeated
    return if goods_id.nil? || order.nil?

    repeated = order.items.any? { |other| other.goods_id == goods_id && !same_item?(other) }
    errors.add(:goods, :repeated) if repeated
  end

  def same_item?(other)
    other.equal?(self) || (persisted? && other.id == id)
  end
end

# == Schema Information
#
# Table name: order_items
#
#  id         :bigint           not null, primary key
#  price      :decimal(12, 2)
#  quantity   :decimal(12, 4)   not null
#  total      :decimal(12, 2)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  goods_id   :bigint
#  order_id   :bigint           not null
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
