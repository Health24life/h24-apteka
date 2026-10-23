# frozen_string_literal: true

class Pillbox::Intake < ApplicationRecord
  enum :status, { taken: 'taken', missed: 'missed' }, validate: true
  enum :marked_via, { push: 'push', app: 'app', web: 'web' }, prefix: :via, validate: { allow_nil: true }

  belongs_to :plan, class_name: 'Pillbox::Plan', inverse_of: :intakes
  belongs_to :plan_item, class_name: 'Pillbox::PlanItem', inverse_of: :intakes
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
