# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pillbox::Intake do
  it 'is taken or missed', :aggregate_failures do
    expect(%w[taken missed].map { build(:pillbox_intake, status: it) }).to all(be_valid)
    expect(build(:pillbox_intake, status: 'due')).not_to be_valid
  end

  it 'is marked through a push, the app or the web, or not at all', :aggregate_failures do
    expect([ nil, 'push', 'app', 'web' ].map { build(:pillbox_intake, marked_via: it) }).to all(be_valid)
    expect(build(:pillbox_intake, marked_via: 'sms')).not_to be_valid
  end

  it 'belongs to an item of a plan', :aggregate_failures do
    expect(build(:pillbox_intake, plan_item: nil, plan: create(:pillbox_plan))).not_to be_valid
    expect(build(:pillbox_intake, plan: nil)).not_to be_valid
  end

  it 'goes with the plan when the plan is deleted' do
    intake = create(:pillbox_intake)

    intake.plan.delete

    expect(described_class.exists?(intake.id)).to be(false)
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
