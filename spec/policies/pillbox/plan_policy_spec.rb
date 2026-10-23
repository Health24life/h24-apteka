# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pillbox::PlanPolicy do
  let(:plan) { create(:pillbox_plan) }

  it 'lets an active or paused plan be changed, not a completed one' do
    allowed = %w[active paused completed].to_h do |status|
      plan.status = status
      [ status, described_class.new(plan.user, plan).update? ]
    end

    expect(allowed).to eq('active' => true, 'paused' => true, 'completed' => false)
  end

  it 'finds only the plans of the user' do
    create(:pillbox_plan)

    expect(described_class::Scope.new(plan.user, Pillbox::Plan).resolve).to contain_exactly(plan)
  end
end
