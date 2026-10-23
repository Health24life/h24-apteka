# frozen_string_literal: true

FactoryBot.define do
  factory :pillbox_plan_item, class: 'Pillbox::PlanItem' do
    plan { association :pillbox_plan, strategy: :create }
    user_id { plan&.user_id }
    source { 'manual' }
    name { 'Вітамін D' }
    every_unit { 'day' }
    times { [ '08:00' ] }
    course_mode { 'days' }
    course_days { 7 }
    course_start_date { Date.current }
    anchor_date { course_start_date }
    missed_until { Time.current }
  end
end

# == Schema Information
#
# Table name: pillbox_plan_items
#
#  id                :bigint           not null, primary key
#  anchor_date       :date             not null
#  course_days       :integer
#  course_end_date   :date
#  course_mode       :string           not null
#  course_start_date :date             not null
#  discarded_at      :datetime
#  dosage            :string
#  every_n           :integer          default(1), not null
#  every_unit        :string           not null
#  missed_until      :datetime         not null
#  name              :string
#  position          :integer          default(0), not null
#  reminder_mode     :string           default("once"), not null
#  schedule_version  :integer          default(1), not null
#  source            :string           not null
#  times             :jsonb            not null
#  weekdays          :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  goods_id          :bigint
#  plan_id           :bigint           not null
#  user_id           :integer          not null
#
# Indexes
#
#  index_pillbox_plan_items_on_goods_id  (goods_id)
#  index_pillbox_plan_items_on_plan_id   (plan_id)
#  index_pillbox_plan_items_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (goods_id => catalog_goods.id) ON DELETE => nullify
#  fk_rails_...  (plan_id => pillbox_plans.id) ON DELETE => cascade
#
