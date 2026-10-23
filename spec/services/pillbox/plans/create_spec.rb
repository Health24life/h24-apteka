# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pillbox::Plans::Create do
  include ActiveSupport::Testing::TimeHelpers

  # 2026-11-01 00:30 in Kyiv is still 2026-10-31 in UTC.
  around { travel_to(Time.utc(2026, 10, 31, 22, 30), &it) }

  let(:user_id) { create(:h24_core_user).id }

  def item(**attrs)
    { source: 'manual', name: 'Вітамін D', every_unit: 'day', times: %w[08:00], course_mode: 'days', course_days: 7 }
      .merge(attrs)
  end

  def create_plan(**attrs)
    described_class.call(
      user_id:,
      attributes: {
        title: 'Застуда',
        timezone: 'Europe/Kyiv',
        items: [ item ]
      }.merge(attrs)
    )
  end

  it 'saves the plan of the user with its items in the order of the request', :aggregate_failures do
    plan = create_plan(items: [ item(name: 'A'), item(name: 'B', times: %w[20:00 08:00]) ])

    expect(plan).to be_persisted
    expect(plan).to have_attributes(user_id:, status: 'active', title: 'Застуда')
    expect(plan.items.map { [ it.name, it.position, it.times, it.schedule_version ] })
      .to eq([ [ 'A', 0, %w[08:00], 1 ], [ 'B', 1, %w[08:00 20:00], 1 ] ])
  end

  it 'gives the items the owner of the plan and normalizes their schedules', :aggregate_failures do
    item = create_plan(items: [ item(every_unit: 'day', weekdays: [ 1 ]) ]).items.first

    expect(item.user_id).to eq(user_id)
    expect([ item.weekdays, item.course_end_date ]).to eq([ [], Date.new(2026, 11, 7) ])
  end

  it 'starts the courses today in the time zone of the plan', :aggregate_failures do
    item = create_plan.items.first

    expect([ item.course_start_date, item.anchor_date, item.course_end_date ])
      .to eq([ Date.new(2026, 11, 1), Date.new(2026, 11, 1), Date.new(2026, 11, 7) ])
    expect(item.missed_until).to eq(Time.current)
  end

  it 'starts the courses on the day the client chose' do
    item = create_plan(start_date: '2026-11-05').items.first

    expect([ item.course_start_date, item.anchor_date ]).to eq([ Date.new(2026, 11, 5), Date.new(2026, 11, 5) ])
  end

  it 'takes the position the client sent' do
    plan = create_plan(items: [ item(name: 'A', position: 5), item(name: 'B', position: 1) ])

    expect(plan.reload.items.map(&:name)).to eq(%w[B A])
  end

  it 'refuses a start date that is not a date' do
    expect(create_plan(start_date: 'abc').errors.of_kind?(:start_date, :invalid)).to be(true)
  end

  it 'keeps nothing when one item is invalid', :aggregate_failures do
    plan = create_plan(title: '', items: [ item, item(times: []) ])

    expect(plan).not_to be_persisted
    expect(plan.errors.attribute_names).to contain_exactly(:title, :'items[1].times')
    expect([ Pillbox::Plan.count, Pillbox::PlanItem.count ]).to eq([ 0, 0 ])
  end

  it 'ignores attributes the plan does not take' do
    other_user = create(:h24_core_user).id

    expect(create_plan(user_id: other_user, status: 'completed')).to have_attributes(user_id:, status: 'active')
  end

  describe 'reminders' do
    before { allow(Pillbox::Reminders::TopUp).to receive(:call) }

    it 'tops up the reminders of the new items once the plan is saved' do
      plan = create_plan

      expect(Pillbox::Reminders::TopUp).to have_received(:call).with(plan.items, Time.current)
    end

    it 'tops up nothing when the plan is not saved' do
      create_plan(title: '')

      expect(Pillbox::Reminders::TopUp).not_to have_received(:call)
    end
  end
end
