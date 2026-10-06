# frozen_string_literal: true

class Order < ApplicationRecord
  STATES = %w[cart].freeze

  enum :state, STATES.index_with(&:itself), validate: true

  has_secure_token :token
  has_secure_token :share_token

  # A shared link must keep working, so the link token never changes.
  attr_readonly :share_token

  belongs_to :drugstore, class_name: 'Catalog::Drugstore', inverse_of: :orders
  belongs_to :provider, inverse_of: :orders

  has_many :items, class_name: 'Order::Item', inverse_of: :order, dependent: :destroy
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
