# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    # Saved first: saving a new parent later, while linking it, would cascade into this unsaved order.
    provider { association :provider, strategy: :create }
    drugstore { association :catalog_drugstore, strategy: :create }

    transient do
      items_count { 1 }
      serve_drugstore { true }
    end

    # An order that left the cart: everything a sent order must have, and the pick-up paid in the pharmacy.
    trait :sent do
      state { 'submitted' }
      personal_data_consent_at { Time.current }
      customer_first_name { 'Anna' }
      customer_phone_number { '380501234567' }
      sequence(:own_number) { "H24-#{it.to_s.rjust(10, '0')}" }
      sequence(:provider_drugstore_external_id, &:to_s)
      sequence(:provider_order_number) { "PP#{it}" }
      drugstore_name { 'Pharmacy' }
      delivery { association :order_delivery, order: instance, strategy: :build }
      payment { association :order_payment, order: instance, strategy: :build }
    end

    trait :submitted do
      sent
    end

    trait :submission_failed do
      sent
      state { 'submission_failed' }
      provider_order_number { nil }
    end

    after(:build) do |order, evaluator|
      ProviderLinking.link(order.provider, order.drugstore) if evaluator.serve_drugstore
      evaluator.items_count.times { order.items << build(:order_item, order:) }
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
