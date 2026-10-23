# frozen_string_literal: true

FactoryBot.define do
  factory :pillbox_plan, class: 'Pillbox::Plan' do
    user { association :h24_core_user, strategy: :create }
    title { 'Застуда' }
    timezone { 'Europe/Kyiv' }
    items { [ association(:pillbox_plan_item, plan: instance, strategy: :build) ] }

    after(:build) { |plan| plan.items.each { it.user_id = plan.user_id } }
  end
end

# == Schema Information
#
# Table name: pillbox_plans
#
#  id              :bigint           not null, primary key
#  completed_at    :datetime
#  missed_days     :integer          default(0), not null
#  paused_at       :datetime
#  status          :string           default("active"), not null
#  timezone        :string           not null
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  source_order_id :bigint
#  user_id         :integer          not null
#
# Indexes
#
#  index_pillbox_plans_on_source_order_id  (source_order_id)
#  index_pillbox_plans_on_timezone         (timezone)
#  index_pillbox_plans_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (source_order_id => orders.id) ON DELETE => nullify
#
