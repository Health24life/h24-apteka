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

  it 'knows the states of a sent order as well', :aggregate_failures do
    described_class::STATES.each { |state| expect(build(:order, state:)).to be_valid }
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

  describe 'binding to a pharmacy and a provider' do
    let(:refused) do
      [ build(:order, serve_drugstore: false),
        build(:order, drugstore: create(:catalog_drugstore, hidden: true)),
        build(:order, provider: create(:provider, active: false)) ]
    end

    it 'refuses a pharmacy the provider does not serve', :aggregate_failures do
      unserved = build(:order, serve_drugstore: false)

      expect(unserved).not_to be_valid
      expect(unserved.errors).to be_added(:drugstore, :not_served_by_provider)
    end

    it 'refuses a pharmacy that only another provider serves' do
      drugstore = create(:catalog_drugstore)
      ProviderLinking.link(create(:provider), drugstore)

      expect(build(:order, drugstore:, serve_drugstore: false)).not_to be_valid
    end

    it 'refuses a pharmacy the administrator hid', :aggregate_failures do
      hidden = build(:order, drugstore: create(:catalog_drugstore, hidden: true))

      expect(hidden).not_to be_valid
      expect(hidden.errors).to be_added(:drugstore, :hidden)
    end

    it 'accepts a pharmacy with incomplete data and a pharmacy withdrawn by the sync', :aggregate_failures do
      expect(build(:order, drugstore: create(:catalog_drugstore, incomplete: true))).to be_valid
      expect(build(:order, drugstore: create(:catalog_drugstore, withdrawn: true))).to be_valid
    end

    it 'refuses a disabled provider', :aggregate_failures do
      disabled = build(:order, provider: create(:provider, active: false))

      expect(disabled).not_to be_valid
      expect(disabled.errors).to be_added(:provider, :disabled)
    end

    it 'leaves a saved cart alone when its provider is disabled later', :aggregate_failures do
      saved = create(:order)
      saved.provider.update!(active: false)

      expect(saved.reload).to be_valid
      expect(saved.save).to be(true)
    end

    it 'keeps the pharmacy and the provider fixed once saved', :aggregate_failures do
      saved = create(:order)

      expect { saved.update(drugstore_id: create(:catalog_drugstore).id) }
        .to raise_error(ActiveRecord::ReadonlyAttributeError)
      expect { saved.update(provider_id: create(:provider).id) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end

    it 'words every refusal in the locale files', :aggregate_failures do
      messages = refused.flat_map { |order| order.tap(&:validate).errors.full_messages }

      expect(messages).not_to be_empty
      expect(messages.grep(/translation missing/i)).to be_empty
    end
  end

  describe 'an empty cart' do
    it 'cannot be saved', :aggregate_failures do
      empty = build(:order, items_count: 0)

      expect(empty).not_to be_valid
      expect(empty.errors).to be_added(:items, :blank)
    end

    {
      'item.destroy!' => ->(_cart, item) { item.destroy! },
      'items.destroy' => ->(cart, item) { cart.items.destroy(item) },
      'items.delete' => ->(cart, item) { cart.items.delete(item) }
    }.each do |way, remove|
      it "is removed together with its last item through #{way}" do
        cart = create(:order, items_count: 2)
        first, last = cart.items.to_a
        remove.call(cart, first)

        expect { remove.call(cart, last) }.to change { described_class.exists?(cart.id) }.from(true).to(false)
      end
    end

    %i[clear delete_all destroy_all].each do |way|
      it "is removed when all its items are removed through items.#{way}" do
        cart = create(:order, items_count: 2)

        cart.items.public_send(way)

        expect(described_class.exists?(cart.id)).to be(false)
      end
    end

    it 'is not removed when it is no longer a cart and its last item is removed' do
      sent = create(:order)
      sent.update_column(:state, 'submitted') # rubocop:disable Rails/SkipsModelValidations

      expect { sent.items.first.destroy! }.not_to change { described_class.exists?(sent.id) }.from(true)
    end

    it 'is destroyed together with its items without errors', :aggregate_failures do
      cart = create(:order, items_count: 2)

      expect { cart.destroy! }.to change(Order::Item, :count).by(-2)
      expect(described_class.exists?(cart.id)).to be(false)
    end

    it 'does not look for the remaining items of each item destroyed together with it' do
      cart = create(:order, items_count: 2)
      queries = []
      record = ->(*, payload) { queries << payload[:sql] }

      ActiveSupport::Notifications.subscribed(record, 'sql.active_record') { cart.destroy! }

      expect(queries.grep(/SELECT 1 AS one FROM "order_items"/)).to be_empty
    end
  end

  describe 'owner' do
    it 'is a core user or nobody, meaning a guest', :aggregate_failures do
      expect(build(:order, user_id: create(:h24_core_user).id)).to be_valid
      expect(build(:order, user_id: nil)).to be_valid
    end

    it 'allows one cart per user', :aggregate_failures do
      user = create(:h24_core_user)
      create(:order, user_id: user.id)
      second = build(:order, user_id: user.id)

      expect(second).not_to be_valid
      expect(second.errors).to be_of_kind(:user_id, :taken)
    end

    it 'allows any number of guest carts' do
      expect(create_list(:order, 2, user_id: nil)).to all(be_persisted)
    end

    it 'lets a user start a new cart after the previous one was sent' do
      user = create(:h24_core_user)
      create(:order, user_id: user.id).update_column(:state, 'submitted') # rubocop:disable Rails/SkipsModelValidations

      expect(build(:order, user_id: user.id)).to be_valid
    end

    it 'allows a user any number of orders that are no longer carts' do
      user = create(:h24_core_user)
      orders = create_list(:order, 2)
      orders.each { |order| order.update_columns(user_id: user.id, state: 'submitted') } # rubocop:disable Rails/SkipsModelValidations

      expect(orders.map(&:reload)).to all(have_attributes(user_id: user.id, state: 'submitted'))
    end
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

    it 'accepts every known state' do
      rows = described_class::STATES.map do |state|
        row.merge(state:, token: SecureRandom.hex(12), share_token: SecureRandom.hex(12))
      end

      expect { rows.each { |attributes| store_row(attributes) } }.not_to raise_error
    end

    it 'refuses a second cart of one user' do
      first = create(:order, user_id: create(:h24_core_user).id)

      expect { store_row(row.merge(user_id: first.user_id)) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows any number of guest carts' do
      other = row.merge(token: SecureRandom.hex(12), share_token: SecureRandom.hex(12))

      expect { [ row, other ].each { |attributes| store_row(attributes) } }.not_to raise_error
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
#  index_orders_on_share_token   (share_token) UNIQUE
#  index_orders_on_token         (token) UNIQUE
#  index_orders_on_user_id_cart  (user_id) UNIQUE WHERE (((state)::text = 'cart'::text) AND (user_id IS NOT NULL))
#
# Foreign Keys
#
#  fk_rails_...  (drugstore_id => catalog_drugstores.id)
#  fk_rails_...  (provider_id => providers.id)
#
# Check Constraints
#
#  orders_state_check  (state::text = ANY (ARRAY['cart'::character varying, 'submitted'::character varying, 'submission_failed'::character varying]::text[]))
#
