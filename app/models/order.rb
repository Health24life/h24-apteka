# frozen_string_literal: true

class Order < ApplicationRecord
  STATES = %w[cart submitted submission_failed].freeze
  NAME_LENGTH = 100
  # 380 and nine digits, no plus sign.
  PHONE_FORMAT = /\A380\d{9}\z/

  enum :state, STATES.index_with(&:itself), validate: true

  has_secure_token :token
  has_secure_token :share_token

  # Switching the pharmacy or the provider means clearing the cart, and a shared link must keep working.
  attr_readonly :drugstore_id, :provider_id, :share_token

  belongs_to :drugstore, class_name: 'Catalog::Drugstore', inverse_of: :orders
  belongs_to :provider, inverse_of: :orders
  # The core lives in another database, so there is no foreign key; no user means a guest, known by the token.
  belongs_to :user, class_name: 'H24Core::User', optional: true, inverse_of: :orders

  # An item has no callbacks of its own, so the cart deletes its items in one statement. A cart that loses its last
  # item is removed by Orders::RemoveItem.
  has_many :items, class_name: 'Order::Item', inverse_of: :order, dependent: :delete_all
  # Only a sent order has them; the cart has neither. Saved in the same save! as the order.
  has_one :delivery, class_name: 'Order::Delivery', inverse_of: :order, dependent: :delete, autosave: true
  has_one :payment, class_name: 'Order::Payment', inverse_of: :order, dependent: :delete, autosave: true

  validates :items, presence: true
  validates :user_id, uniqueness: { conditions: -> { cart } }, allow_nil: true, if: :cart?
  # A disabled provider may come back, so carts that already exist stay; they just cannot be created.
  validates :drugstore, served_by_provider: true, not_hidden: true, on: :create
  validates :provider, enabled: true, on: :create
  # A sent order does not care about the provider any more, so the check is on the way out of the cart only.
  validates :provider, enabled: true, if: :leaving_cart?

  validates :customer_first_name, :customer_last_name, :customer_middle_name, length: { maximum: NAME_LENGTH }
  validates :customer_phone_number, format: { with: PHONE_FORMAT }, allow_nil: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :provider_order_number, uniqueness: { scope: :provider_id }, allow_nil: true
  validates :own_number, uniqueness: true, allow_nil: true

  # Mirror the orders_sent_data_check constraint: a cart has none of this data yet.
  with_options unless: :cart? do
    validates :own_number, :customer_first_name, :customer_phone_number, :provider_drugstore_external_id,
              presence: true
    validates :personal_data_consent_at, presence: true
    validates :delivery, :payment, presence: true
  end
  validates :provider_order_number, presence: true, if: :submitted?

  private

  def leaving_cart? = state_changed?(from: 'cart')
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
