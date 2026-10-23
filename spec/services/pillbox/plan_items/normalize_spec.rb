# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pillbox::PlanItems::Normalize do
  let(:start) { Date.new(2026, 11, 1) }

  def normalized(**attrs) = described_class.call(build(:pillbox_plan_item, course_start_date: start, **attrs))

  it 'keeps sorted days of a weekly schedule, 0 being Sunday' do
    expect(normalized(every_unit: 'week', weekdays: [ 3, 0, 3 ]).weekdays).to eq([ 0, 3 ])
  end

  it 'keeps no days for other units' do
    expect(normalized(every_unit: 'day', weekdays: [ 1 ]).weekdays).to eq([])
  end

  it 'leaves days that are not numbers for the validation to name' do
    expect(normalized(every_unit: 'week', weekdays: [ '1', 0 ]).weekdays).to eq([ '1', 0 ])
  end

  it 'ends a course in days on its last day' do
    expect(normalized(course_mode: 'days', course_days: 7).course_end_date).to eq(Date.new(2026, 11, 7))
  end

  it 'counts the days of a course until a date' do
    expect(normalized(course_mode: 'until', course_days: nil, course_end_date: start + 9).course_days).to eq(10)
  end

  it 'has no end in an open course' do
    item = normalized(course_mode: 'open', course_days: 7, course_end_date: start + 3)

    expect([ item.course_days, item.course_end_date ]).to eq([ nil, nil ])
  end
end
