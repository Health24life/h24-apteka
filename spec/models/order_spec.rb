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
    expect(build(:order)).to be_valid
    expect(build(:order, :submitted)).to be_valid
    expect(build(:order, :submission_failed)).to be_valid
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

    it 'is destroyed together with its items without errors', :aggregate_failures do
      cart = create(:order, items_count: 2)

      expect { cart.destroy! }.to change(Order::Item, :count).by(-2)
      expect(described_class.exists?(cart.id)).to be(false)
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
      create(:order, :submitted, user_id: user.id)

      expect(build(:order, user_id: user.id)).to be_valid
    end

    it 'allows a user any number of orders that are no longer carts' do
      user = create(:h24_core_user)
      orders = create_list(:order, 2, :submitted, user_id: user.id)

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

  # Fills a cart with what a sent order must have, as the checkout would before the state changes.
  def send_out(cart, **overrides)
    cart.assign_attributes(state: 'submitted', personal_data_consent_at: Time.current, customer_first_name: 'Anna',
                           customer_phone_number: '380501234567', own_number: 'H24-0000000009',
                           provider_drugstore_external_id: '42', provider_order_number: 'PP9', **overrides)
    cart.build_delivery(delivery_type_code: 'pick_up')
    cart.build_payment(payment_type_code: 'cash_in_store')
  end

  describe 'a sent order' do
    subject(:sent) { build(:order, :submitted) }

    it { is_expected.to be_valid }
    it { is_expected.to have_one(:delivery).inverse_of(:order) }
    it { is_expected.to have_one(:payment).inverse_of(:order) }

    it 'refuses to leave the cart without the moment of consent', :aggregate_failures do
      cart = create(:order)
      send_out(cart, personal_data_consent_at: nil)

      expect(cart).not_to be_valid
      expect(cart.errors).to be_added(:personal_data_consent_at, :blank)
    end

    it 'keeps a cart without any customer data' do
      expect(build(:order)).to be_valid
    end

    it 'refuses an empty name, phone, own number and pharmacy ID of the provider', :aggregate_failures do
      blanks = [ nil, '', '   ' ]
      %i[customer_first_name customer_phone_number own_number provider_drugstore_external_id].each do |attribute|
        blanks.each { |blank| expect(build(:order, :submitted, attribute => blank)).not_to be_valid }
      end
    end

    it 'does not need the last name, the patronymic and the e-mail', :aggregate_failures do
      order = build(:order, :submitted, customer_last_name: nil, customer_middle_name: nil, customer_email: nil)

      expect(order).to be_valid
    end

    it 'limits the names to a hundred characters', :aggregate_failures do
      %i[customer_first_name customer_last_name customer_middle_name].each do |attribute|
        expect(build(:order, :submitted, attribute => 'a' * 101)).not_to be_valid
        expect(build(:order, :submitted, attribute => 'a' * 100)).to be_valid
      end
    end

    it 'takes a phone as 380 and nine digits only', :aggregate_failures do
      valid = %w[380501234567 380000000000]
      malformed = %w[+380501234567 0501234567 38050123456 3805012345678 38050123456a]

      valid.each { |phone| expect(build(:order, :submitted, customer_phone_number: phone)).to be_valid }
      malformed.each { |phone| expect(build(:order, :submitted, customer_phone_number: phone)).not_to be_valid }
    end

    it 'refuses a malformed e-mail but takes a proper one', :aggregate_failures do
      expect(build(:order, :submitted, customer_email: 'anna@')).not_to be_valid
      expect(build(:order, :submitted, customer_email: 'anna@example.com')).to be_valid
    end

    it 'does not create an account unless asked', :aggregate_failures do
      expect(described_class.new.register_account).to be(false)
      expect(create(:order, :submitted).reload.register_account).to be(false)
    end

    it 'needs a delivery and a payment', :aggregate_failures do
      expect(build(:order, :submitted, delivery: nil)).not_to be_valid
      expect(build(:order, :submitted, payment: nil)).not_to be_valid
    end

    it 'saves its delivery and payment in the same save', :aggregate_failures do
      saved = create(:order, :submitted)

      expect(saved.reload.delivery).to be_persisted
      expect(saved.payment).to be_persisted
    end

    it 'removes its delivery and payment with it', :aggregate_failures do
      saved = create(:order, :submitted)

      expect { saved.destroy! }.to change(Order::Delivery, :count).by(-1).and change(Order::Payment, :count).by(-1)
    end

    it 'keeps its provider payload and progress as objects' do
      expect(create(:order, :submitted).reload).to have_attributes(provider_payload: {}, progress: {})
    end
  end

  describe 'own number' do
    it 'must be unique', :aggregate_failures do
      first = create(:order, :submitted)
      second = build(:order, :submitted, own_number: first.own_number)

      expect(second).not_to be_valid
      expect(second.errors).to be_added(:own_number, :taken, value: first.own_number)
    end
  end

  describe 'state of Health24' do
    it 'requires the number of the provider for a submitted order', :aggregate_failures do
      order = build(:order, :submitted, provider_order_number: nil)

      expect(order).not_to be_valid
      expect(order.errors).to be_added(:provider_order_number, :blank)
    end

    it 'does not require it after a failed submission' do
      expect(build(:order, :submission_failed)).to be_valid
    end

    it 'lets a failed order be sent again with the same own number', :aggregate_failures do
      failed = create(:order, :submission_failed)

      expect { failed.update!(state: 'submitted', provider_order_number: 'PP-1') }
        .not_to(change { failed.reload.own_number })
      expect(failed).to be_submitted
    end

    it 'refuses the number of the provider that another order of this provider has', :aggregate_failures do
      first = create(:order, :submitted)
      second = build(:order, :submitted, provider: first.provider, drugstore: first.drugstore,
                                         provider_order_number: first.provider_order_number)

      expect(second).not_to be_valid
      expect(second.errors).to be_of_kind(:provider_order_number, :taken)
    end

    it 'accepts the same number of another provider' do
      first = create(:order, :submitted)

      expect(build(:order, :submitted, provider_order_number: first.provider_order_number)).to be_valid
    end
  end

  describe 'leaving the cart' do
    it 'is refused through a disabled provider and the order stays a cart', :aggregate_failures do
      cart = create(:order).tap { it.provider.update!(active: false) }
      send_out(cart)

      expect(cart).not_to be_valid
      expect(cart.errors).to be_added(:provider, :disabled)
      expect(cart.reload).to be_cart
    end

    it 'is allowed through an enabled provider', :aggregate_failures do
      cart = create(:order)
      send_out(cart)

      expect(cart).to be_valid
    end

    it 'does not look at the provider once the order is sent' do
      sent = create(:order, :submitted)
      sent.provider.update!(active: false)

      expect(sent.update(status_name: 'processed_by_pharmacy', status_synced_at: Time.current)).to be(true)
    end

    it 'does not look at what the provider supports once the order is sent' do
      sent = create(:order, :submitted)
      sent.provider.update!(supports_delivery: false)
      sent.delivery.update_columns(delivery_type_code: 'ukr_post') # rubocop:disable Rails/SkipsModelValidations
      create(:order_delivery_address, delivery: sent.delivery)

      expect(sent.reload.update(status_name: 'canceled')).to be(true)
    end
  end

  describe 'status of the provider' do
    it 'is stored as sent, without checks', :aggregate_failures do
      sent = create(:order, :submitted, status_name: 'awaiting_courier', status_comment: 'Wait', cancel_reason: nil,
                                        progress: { step: 3, completed: false, label: 'Courier' })

      expect(sent.reload).to have_attributes(status_name: 'awaiting_courier', status_comment: 'Wait')
      expect(sent.progress).to eq('step' => 3, 'completed' => false, 'label' => 'Courier')
    end
  end

  describe 'refusals of a sent order' do
    it 'are worded in the locale files', :aggregate_failures do
      refused = [ build(:order, :submitted, customer_phone_number: '1'), build(:order, :submitted, own_number: ''),
                  build(:order, :submitted, customer_email: 'a@'), build(:order, :submitted, delivery: nil) ]
      messages = refused.flat_map { |record| record.tap(&:validate).errors.full_messages }

      expect(messages).not_to be_empty
      expect(messages.grep(/translation missing/i)).to be_empty
    end
  end

  describe 'database level, bypassing validations, for a sent order' do
    let(:saved) { create(:order) }
    let(:now) { Time.current }
    let(:row) do
      { drugstore_id: saved.drugstore_id, provider_id: saved.provider_id, state: 'submitted',
        token: SecureRandom.hex(12), share_token: SecureRandom.hex(12), created_at: now, updated_at: now,
        personal_data_consent_at: now, own_number: 'H24-0000000001', customer_first_name: 'Anna',
        customer_phone_number: '380501234567', provider_drugstore_external_id: '42', provider_order_number: 'PP1' }
    end

    def store_row(attributes)
      described_class.insert_all!([ attributes ]) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'accepts a complete sent order' do
      expect { store_row(row) }.not_to raise_error
    end

    it 'refuses a sent order missing any required value, empty or made of spaces', :aggregate_failures do
      texts = %i[own_number customer_first_name customer_phone_number provider_drugstore_external_id]
      texts.product([ nil, '', '   ' ]).push([ :personal_data_consent_at, nil ]).each do |column, value|
        expect { store_row(row.merge(column => value)) }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    it 'keeps a cart without any of them' do
      expect { store_row(row.slice(:drugstore_id, :provider_id, :token, :share_token, :created_at, :updated_at)) }
        .not_to raise_error
    end

    it 'refuses a submitted order without the number of the provider', :aggregate_failures do
      [ nil, '', '  ' ].each do |number|
        expect { store_row(row.merge(provider_order_number: number)) }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    it 'refuses a malformed phone' do
      expect { store_row(row.merge(customer_phone_number: '+380501234567')) }
        .to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'refuses a repeated own number' do
      store_row(row)

      expect { store_row(row.merge(token: SecureRandom.hex(12), share_token: SecureRandom.hex(12))) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'refuses a repeated number of the provider within one provider' do
      store_row(row)
      other = row.merge(own_number: 'H24-0000000002', token: SecureRandom.hex(12), share_token: SecureRandom.hex(12))

      expect { store_row(other) }.to raise_error(ActiveRecord::RecordNotUnique)
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

    def sent_data(state)
      { personal_data_consent_at: now, own_number: "H24-#{state}", customer_first_name: 'Anna',
        customer_phone_number: '380501234567', provider_drugstore_external_id: '42',
        provider_order_number: "PP-#{state}" }
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
      rows = described_class.states.values.map do |state|
        sent = state == 'cart' ? {} : sent_data(state)
        row.merge(sent).merge(state:, token: SecureRandom.hex(12), share_token: SecureRandom.hex(12))
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

  describe 'search' do
    it 'finds an order by the whole phone written in any usual way', :aggregate_failures do
      order = create(:order, :submitted, customer_phone_number: '380501234567')
      create(:order, :submitted, customer_phone_number: '380671234567')

      expect(described_class.customer_phone_eq('+38 (050) 123-45-67')).to contain_exactly(order)
      expect(described_class.customer_phone_eq('0501234567')).to contain_exactly(order)
    end

    it 'finds nothing by a part of a phone' do
      create(:order, :submitted, customer_phone_number: '380501234567')

      expect(described_class.customer_phone_eq('4567')).to be_empty
    end

    it 'keeps the guest tokens and the personal data out of filters and sorting', :aggregate_failures do
      hidden = %w[token share_token customer_first_name customer_last_name customer_middle_name customer_phone_number
                  customer_email provider_payload]

      expect(described_class.ransackable_attributes & hidden).to be_empty
      expect(described_class.ransortable_attributes & hidden).to be_empty
      expect(described_class.ransackable_associations).to contain_exactly('drugstore', 'provider')
    end

    it 'ignores a filter on a guest token' do
      order = create(:order)

      expect(described_class.ransack(token_start: order.token[0, 3], token_eq: 'nothing').result).to include(order)
    end
  end
end

# == Schema Information
#
# Table name: orders
#
#  id                             :bigint           not null, primary key
#  cancel_reason                  :string
#  customer_email                 :string
#  customer_first_name            :string(100)
#  customer_last_name             :string(100)
#  customer_middle_name           :string(100)
#  customer_phone_number          :string
#  drugstore_address              :string
#  drugstore_name                 :string
#  drugstore_phone                :string
#  own_number                     :string
#  personal_data_consent_at       :datetime
#  progress                       :jsonb            not null
#  provider_order_number          :string
#  provider_payload               :jsonb            not null
#  provider_updated_at            :datetime
#  register_account               :boolean          default(FALSE), not null
#  share_token                    :string           not null
#  state                          :string           default("cart"), not null
#  status_comment                 :string
#  status_name                    :string
#  status_synced_at               :datetime
#  token                          :string           not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  drugstore_id                   :bigint           not null
#  provider_drugstore_external_id :string
#  provider_id                    :bigint           not null
#  user_id                        :integer
#
# Indexes
#
#  index_orders_on_own_number                             (own_number) UNIQUE
#  index_orders_on_provider_id_and_provider_order_number  (provider_id,provider_order_number) UNIQUE
#  index_orders_on_share_token                            (share_token) UNIQUE
#  index_orders_on_token                                  (token) UNIQUE
#  index_orders_on_user_id_cart                           (user_id) UNIQUE WHERE (((state)::text = 'cart'::text) AND (user_id IS NOT NULL))
#
# Foreign Keys
#
#  fk_rails_...  (drugstore_id => catalog_drugstores.id)
#  fk_rails_...  (provider_id => providers.id)
#
# Check Constraints
#
#  orders_customer_phone_number_check            (customer_phone_number IS NULL OR customer_phone_number::text ~ '^380[0-9]{9}$'::text)
#  orders_provider_objects_check                 (jsonb_typeof(progress) = 'object'::text AND jsonb_typeof(provider_payload) = 'object'::text)
#  orders_sent_data_check                        (state::text = 'cart'::text OR personal_data_consent_at IS NOT NULL AND COALESCE(btrim(own_number::text), ''::text) <> ''::text AND COALESCE(btrim(customer_first_name::text), ''::text) <> ''::text AND COALESCE(btrim(customer_phone_number::text), ''::text) <> ''::text AND COALESCE(btrim(provider_drugstore_external_id::text), ''::text) <> ''::text)
#  orders_state_check                            (state::text = ANY (ARRAY['cart'::character varying, 'submitted'::character varying, 'submission_failed'::character varying]::text[]))
#  orders_submitted_provider_order_number_check  (state::text <> 'submitted'::text OR COALESCE(btrim(provider_order_number::text), ''::text) <> ''::text)
#
