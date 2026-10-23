# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pillbox::Plans::Update do
  include ActiveSupport::Testing::TimeHelpers

  # The plan was created a week ago; now is 10:00 in Kyiv.
  around { travel_to(Time.zone.parse('2026-11-08 08:00 UTC'), &it) }

  let(:week_ago) { Date.new(2026, 11, 1) }
  let(:plan) do
    create(
      :pillbox_plan,
      items: [
        build(:pillbox_plan_item, plan: nil, name: 'A', position: 0, course_start_date: week_ago, course_days: 30),
        build(:pillbox_plan_item, plan: nil, name: 'B', position: 1, course_start_date: week_ago, course_days: 30)
      ]
    ).reload
  end
  let(:first) { plan.items.first }
  let(:second) { plan.items.second }

  before { allow(Pillbox::Reminders::TopUp).to receive(:call) }

  def update(**attributes) = described_class.call(plan, attributes:)

  def medicine(**attrs)
    {
      source: 'manual',
      name: 'C',
      every_unit: 'day',
      times: %w[12:00],
      course_mode: 'days',
      course_days: 5
    }.merge(attrs)
  end

  it 'changes the title' do
    expect(update(title: 'Нова назва').reload.title).to eq('Нова назва')
  end

  it 'keeps the schedule version when only the dosage changes', :aggregate_failures do
    update(items_attributes: [ { id: first.id, dosage: '1 капсула' } ])

    expect(first.reload).to have_attributes(dosage: '1 капсула', schedule_version: 1)
    expect(Pillbox::Reminders::TopUp).to have_received(:call).with([], Time.current)
  end

  it 'starts a changed schedule anew from now, keeping the start of the course', :aggregate_failures do
    update(items_attributes: [ { id: first.id, times: %w[09:00 21:00] } ])

    expect(first.reload).to have_attributes(
      times: %w[09:00 21:00],
      schedule_version: 2,
      missed_until: Time.current,
      course_start_date: week_ago,
      anchor_date: week_ago
    )
  end

  it 'counts every N from today when the period changes' do
    update(items_attributes: [ { id: first.id, every_n: 3 } ])

    expect(first.reload.anchor_date).to eq(Date.new(2026, 11, 8))
  end

  it 'adds a medicine that starts today, after the others', :aggregate_failures do
    added = update(items_attributes: [ medicine ]).reload.items.last

    expect(added).to have_attributes(
      name: 'C',
      position: 2,
      course_start_date: Date.new(2026, 11, 8),
      user_id: plan.user_id
    )
    expect(added.course_end_date).to eq(Date.new(2026, 11, 12))
  end

  it 'adds a medicine asked to be discarded as a usual one' do
    expect(update(items_attributes: [ medicine(discard: true) ]).reload.items.map(&:name)).to eq(%w[A B C])
  end

  it 'discards a medicine and keeps its intakes', :aggregate_failures do
    intake = create(:pillbox_intake, plan_item: second, plan:)

    updated = update(items_attributes: [ { id: second.id, discard: true } ])

    expect(updated.reload.items.map(&:name)).to eq(%w[A])
    expect(second.reload).to have_attributes(discarded_at: Time.current, missed_until: Time.current)
    expect(Pillbox::Intake.exists?(intake.id)).to be(true)
  end

  it 'does not discard the last medicine', :aggregate_failures do
    updated = update(items_attributes: [ { id: first.id, discard: true }, { id: second.id, discard: true } ])

    expect(updated.errors.of_kind?(:items, :blank)).to be(true)
    expect(plan.reload.items.count).to eq(2)
  end

  it 'changes nothing when one change is invalid', :aggregate_failures do
    updated = update(
      title: 'Нова назва',
      items_attributes: [
        { id: first.id, dosage: 'x' },
        { id: second.id, times: [] }
      ]
    )

    expect(updated.errors.attribute_names).to eq([ :'items[1].times' ])
    expect([ plan.reload.title, first.reload.dosage ]).to eq([ 'Застуда', nil ])
  end

  it 'refuses a medicine already discarded' do
    second.update!(discarded_at: 1.day.ago)

    expect { update(items_attributes: [ { id: second.id, dosage: 'x' } ]) }
      .to raise_error(an_instance_of(ActiveRecord::RecordNotFound).and(having_attributes(model: 'Pillbox::PlanItem')))
  end

  describe 'reminders' do
    it 'tops up the new medicines and those whose schedule changed' do
      updated = update(
        items_attributes: [
          { id: first.id, times: %w[09:00] },
          { id: second.id, name: 'B2' },
          medicine
        ]
      )

      expect(Pillbox::Reminders::TopUp).to have_received(:call).with([ first, updated.items.last ], Time.current)
    end

    it 'tops up nothing for a paused plan' do
      plan.update!(status: 'paused')

      update(items_attributes: [ medicine ])

      expect(Pillbox::Reminders::TopUp).not_to have_received(:call)
    end
  end
end
