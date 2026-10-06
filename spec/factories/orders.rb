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
