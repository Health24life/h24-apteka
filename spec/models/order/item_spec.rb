# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order::Item do
  subject(:item) { build(:order_item) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:order).inverse_of(:items) }

  describe 'SKU' do
    it 'is required', :aggregate_failures do
      without_sku = build(:order_item, goods: nil)

      expect(without_sku).not_to be_valid
      expect(without_sku.errors).to be_added(:goods, :blank)
    end

    it 'must be in the catalog of the cart provider', :aggregate_failures do
      unserved = build(:order_item, served: false)

      expect(unserved).not_to be_valid
      expect(unserved.errors).to be_added(:goods, :not_served_by_provider)
    end

    it 'must not be hidden by an administrator', :aggregate_failures do
      hidden = build(:order_item, goods: create(:catalog_goods, hidden: true))

      expect(hidden).not_to be_valid
      expect(hidden.errors).to be_added(:goods, :hidden)
    end

    it 'must not belong to a goods group the administrator hid', :aggregate_failures do
      group = create(:catalog_goods_group, hidden: true)
      in_hidden_group = build(:order_item, goods: create(:catalog_goods, goods_group: group))

      expect(in_hidden_group).not_to be_valid
      expect(in_hidden_group.errors).to be_added(:goods, :hidden)
    end

    it 'may be withdrawn by the sync' do
      expect(build(:order_item, goods: create(:catalog_goods, withdrawn: true))).to be_valid
    end

    it 'cannot repeat in the same cart', :aggregate_failures do
      cart = create(:order)
      repeated = build(:order_item, order: cart, goods: cart.items.first.goods)

      expect(repeated).not_to be_valid
      expect(repeated.errors).to be_added(:goods_id, :repeated)
    end

    it 'cannot repeat inside a cart that is saved for the first time' do
      sku = create(:catalog_goods)
      cart = build(:order, items_count: 0)
      2.times { cart.items << build(:order_item, order: cart, goods: sku) }

      expect(cart).not_to be_valid
    end

    it 'does not clash with itself when a saved item is updated through a separate copy' do
      cart = create(:order)

      expect(described_class.find(cart.items.first.id).update(quantity: 2)).to be(true)
    end
  end

  describe 'quantity' do
    it 'accepts a whole and a fractional number', :aggregate_failures do
      expect(build(:order_item, quantity: 3)).to be_valid
      expect(build(:order_item, quantity: '0.5')).to be_valid
    end

    it 'refuses zero, a negative number and a missing value', :aggregate_failures do
      [ 0, -1, nil ].each { |quantity| expect(build(:order_item, quantity:)).not_to be_valid }
    end

    it 'refuses a fraction the column would round down to zero' do
      expect(build(:order_item, quantity: '0.00001')).not_to be_valid
    end

    it 'refuses a number that does not fit the column' do
      expect(build(:order_item, quantity: 100_000_000)).not_to be_valid
    end

    it 'stores the largest number that fits the column' do
      expect(create(:order).items.first.update(quantity: '99999999.9999')).to be(true)
    end
  end

  describe 'price' do
    it 'is never stored in a cart', :aggregate_failures do
      priced = build(:order_item, price: 10)

      expect(priced).not_to be_valid
      expect(priced.errors).to be_added(:price, :present)
      expect(build(:order_item, total: 10)).not_to be_valid
    end
  end

  describe 'provider of the cart' do
    let(:cart) { create(:order) }

    before { cart.provider.update!(active: false) }

    it 'must be enabled for a new item', :aggregate_failures do
      added = build(:order_item, order: cart)

      expect(added).not_to be_valid
      expect(added.errors).to be_added(:provider, :disabled)
    end

    it 'does not matter for an item that is already in the cart' do
      expect(cart.items.first.update(quantity: 2)).to be(true)
    end
  end

  it 'refreshes the change time of its cart' do
    cart = create(:order)
    cart.update_column(:updated_at, 1.day.ago) # rubocop:disable Rails/SkipsModelValidations

    cart.items.first.update!(quantity: 2)

    expect(cart.reload.updated_at).to be_within(1.minute).of(Time.current)
  end

  describe 'refusals' do
    let(:disabled_cart) { create(:order).tap { |cart| cart.provider.update!(active: false) } }
    let(:cart) { create(:order) }
    let(:refused) do
      [ build(:order_item, served: false),
        build(:order_item, goods: create(:catalog_goods, hidden: true)),
        build(:order_item, order: disabled_cart),
        build(:order_item, order: cart, goods: cart.items.first.goods) ]
    end

    it 'are worded in the locale files', :aggregate_failures do
      messages = refused.flat_map { |record| record.tap(&:validate).errors.full_messages }

      expect(messages).not_to be_empty
      expect(messages.grep(/translation missing/i)).to be_empty
    end
  end

  describe 'database level, bypassing validations' do
    let!(:cart) { create(:order) }
    let(:now) { Time.current }
    let(:row) do
      { order_id: cart.id, goods_id: cart.items.first.goods_id, quantity: 1, created_at: now, updated_at: now }
    end

    def store_row(attributes)
      described_class.insert_all!([ attributes ]) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'refuses a zero or negative quantity', :aggregate_failures do
      [ 0, -1 ].each do |quantity|
        expect { store_row(row.merge(quantity:)) }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    it 'refuses an item without an order' do
      expect { store_row(row.merge(order_id: nil)) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'goes with its order when the order is deleted' do
      expect { cart.delete }.to change(described_class, :count).by(-1)
    end
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
