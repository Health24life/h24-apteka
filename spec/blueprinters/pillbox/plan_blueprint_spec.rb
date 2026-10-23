# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pillbox::PlanBlueprint do
  let(:user_id) { create(:h24_core_user).id }

  def created_plan(items)
    Pillbox::Plans::Create.call(
      user_id:,
      attributes: {
        title: 'Застуда',
        timezone: 'Europe/Kyiv',
        items_attributes: items
      }
    )
  end

  def item(**attrs)
    { source: 'manual', every_unit: 'day', times: %w[08:00], course_mode: 'open' }.merge(attrs)
  end

  it 'lists the items of a plan just created by their position' do
    plan = created_plan([ item(name: 'A', position: 2), item(name: 'B', position: 1) ])

    expect(described_class.render_as_hash(plan)[:items].pluck(:name)).to eq(%w[B A])
  end

  it 'shows the plan and its items without the inner state', :aggregate_failures do
    plan = created_plan([ item(name: 'A') ])

    rendered = described_class.render_as_hash(plan)

    expect(rendered.keys).to contain_exactly(:id, :title, :timezone, :status, :source_order_id, :created_at, :items)
    expect(rendered[:items].first.keys).to contain_exactly(
      :id,
      :source,
      :goods_id,
      :name,
      :dosage,
      :position,
      :every_unit,
      :every_n,
      :weekdays,
      :times,
      :reminder_mode,
      :course_mode,
      :course_start_date,
      :course_days,
      :course_end_date
    )
  end
end
