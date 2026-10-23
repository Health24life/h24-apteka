# frozen_string_literal: true

FactoryBot.define do
  factory :pillbox_intake, class: 'Pillbox::Intake' do
    plan_item { association :pillbox_plan_item, strategy: :create }
    plan { plan_item.plan }
    scheduled_date { Date.current }
    scheduled_time { '08:00' }
    due_at { Time.current }
    status { 'taken' }
  end
end

# == Schema Information
#
# Table name: pillbox_intakes
#
#  id             :bigint           not null, primary key
#  due_at         :datetime         not null
#  marked_via     :string
#  scheduled_date :date             not null
#  scheduled_time :string           not null
#  status         :string           not null
#  taken_at       :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  plan_id        :bigint           not null
#  plan_item_id   :bigint           not null
#
# Indexes
#
#  index_pillbox_intakes_on_plan_id_and_scheduled_date       (plan_id,scheduled_date)
#  index_pillbox_intakes_on_plan_item_id_and_scheduled_date  (plan_item_id,scheduled_date)
#
# Foreign Keys
#
#  fk_rails_...  (plan_id => pillbox_plans.id) ON DELETE => cascade
#  fk_rails_...  (plan_item_id => pillbox_plan_items.id) ON DELETE => cascade
#
