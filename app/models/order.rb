# frozen_string_literal: true

class Order < ApplicationRecord
  STATES = %w[cart].freeze

  enum :state, STATES.index_with(&:itself), validate: true

  has_secure_token :token
  has_secure_token :share_token

  # Switching the pharmacy or the provider means clearing the cart, and a shared link must keep working.
  attr_readonly :drugstore_id, :provider_id, :share_token

  belongs_to :drugstore, class_name: 'Catalog::Drugstore', inverse_of: :orders
  belongs_to :provider, inverse_of: :orders
  # The core lives in another database, so there is no foreign key; no user means a guest, known by the token.
  belongs_to :user, class_name: 'H24Core::User', optional: true, inverse_of: :orders

  # :destroy, not :delete_all: items.delete must run the empty-cart callback of the item too. Rails still deletes
  # with plain SQL on delete_all and clear even then, so both are redirected to destroy_all.
  has_many :items, class_name: 'Order::Item', inverse_of: :order, dependent: :destroy do
    def delete_all(*) = destroy_all
  end

  validates :items, presence: true
  validates :user_id, uniqueness: { conditions: -> { cart } }, allow_nil: true, if: :cart?
  # A disabled provider may come back, so carts that already exist stay; they just cannot be created.
  validates :drugstore, served_by_provider: true, not_hidden: true, on: :create
  validates :provider, enabled: true, on: :create
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
#  orders_state_check  (state::text = 'cart'::text)
#
