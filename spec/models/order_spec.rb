# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order do
  subject(:cart) { build(:order) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:drugstore).inverse_of(:orders) }
  it { is_expected.to belong_to(:provider).inverse_of(:orders) }

  it 'starts as a cart' do
    expect(cart).to be_cart
  end

  it 'refuses a state outside the known list' do
    expect(build(:order, state: 'archived')).not_to be_valid
  end

  it 'is reachable from its pharmacy, its provider and its SKU', :aggregate_failures do
    saved = create(:order)

    expect(saved.drugstore.orders).to contain_exactly(saved)
    expect(saved.provider.orders).to contain_exactly(saved)
    expect(saved.items.first.goods.order_items).to contain_exactly(saved.items.first)
  end

  describe 'tokens' do
    it 'generates both tokens as soon as the cart is built', :aggregate_failures do
      expect(cart.token).to be_present
      expect(cart.share_token).to be_present
    end

    it 'gives every cart its own secret token and link token' do
      tokens = create_list(:order, 2).flat_map { [ it.token, it.share_token ] }

      expect(tokens.uniq.size).to eq(4)
    end

    it 'keeps the link token fixed once saved' do
      saved = create(:order)

      expect { saved.update(share_token: 'another') }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end

  describe 'database level, bypassing validations' do
    let(:saved) { create(:order) }
    let(:now) { Time.current }
    let(:row) do
      { drugstore_id: saved.drugstore_id, provider_id: saved.provider_id, state: 'cart', token: SecureRandom.hex(12),
        share_token: SecureRandom.hex(12), created_at: now, updated_at: now }
    end

    def store_row(attributes)
      described_class.insert_all!([ attributes ]) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'refuses a repeated secret token' do
      expect { store_row(row.merge(token: saved.token)) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'refuses a repeated link token' do
      expect { store_row(row.merge(share_token: saved.share_token)) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'refuses a state outside the known list' do
      expect { store_row(row.merge(state: 'archived')) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'refuses a cart of a pharmacy that does not exist' do
      expect { store_row(row.merge(drugstore_id: 0)) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'refuses a cart of a provider that does not exist' do
      expect { store_row(row.merge(provider_id: 0)) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end

# == Schema Information
#
# Table name: orders
#
#  id           :bigint           not null, primary key
#  share_token  :string           not null
#  state        :string           default("cart"), not null
#  token        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  drugstore_id :bigint           not null
#  provider_id  :bigint           not null
#  user_id      :integer
#
# Indexes
#
#  index_orders_on_share_token  (share_token) UNIQUE
#  index_orders_on_token        (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (drugstore_id => catalog_drugstores.id)
#  fk_rails_...  (provider_id => providers.id)
#
# Check Constraints
#
#  orders_state_check  (state::text = 'cart'::text)
#
