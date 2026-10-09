# frozen_string_literal: true

class Order::Item < ApplicationRecord
  # Mirrors decimal(12,4): below the minimum the column rounds down to zero, from the maximum it does not fit.
  MIN_QUANTITY = BigDecimal('0.0001')
  MAX_QUANTITY = BigDecimal(10**8)
  # Mirrors the integer kopecks column.
  MAX_AMOUNT = BigDecimal(2**31) / 100

  belongs_to :order, inverse_of: :items, touch: true
  belongs_to :goods, class_name: 'Catalog::Goods', optional: true, inverse_of: :order_items

  # The provider of an item is the provider of its cart; the validators below read it from here.
  delegate :provider, to: :order, allow_nil: true

  monetize :price_cents, :total_cents, allow_nil: true,
                                       numericality: { greater_than_or_equal_to: 0, less_than: MAX_AMOUNT }

  validates :quantity, numericality: { greater_than_or_equal_to: MIN_QUANTITY, less_than: MAX_QUANTITY }

  # A cart item only points at a SKU: price and availability are always fetched live, so a cart never stores them.
  with_options if: :in_cart? do
    validates :goods, presence: true
    validates :price, :total, absence: true
    validates :goods_id, not_repeated: { among: ->(item) { item.order ? item.order.items.to_a : [] } }
    validates :goods, served_by_provider: true, not_hidden: { via: :goods_group }, on: :create
    # A disabled provider may come back, so items that already exist stay; no new ones are added meanwhile.
    validates :provider, enabled: true, on: :create
  end

  # An item of a sent order is a snapshot. The provider may return a product the catalog does not have, or the same
  # product in several rows, so it has no SKU rules and may carry the price.
  with_options unless: :in_cart? do
    validates :provider_goods_external_id, :name, presence: true
  end

  private

  def in_cart? = order&.cart? || false
end

# == Schema Information
#
# Table name: order_items
#
#  id                         :bigint           not null, primary key
#  image_paths                :jsonb            not null
#  name                       :string
#  price_cents                :integer
#  producer                   :string
#  quantity                   :decimal(12, 4)   not null
#  release_form               :string
#  total_cents                :integer
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
#  order_items_amounts_check      (price_cents >= 0 AND total_cents >= 0)
#  order_items_image_paths_check  (jsonb_typeof(image_paths) = 'array'::text)
#  order_items_quantity_check     (quantity > 0::numeric)
#
