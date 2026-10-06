# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order::Item do
  subject(:item) { build(:order_item) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:order).inverse_of(:items) }

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
