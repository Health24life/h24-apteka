# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pillbox::PlanItem do
  let(:plan) { create(:pillbox_plan) }
  let(:start) { Date.new(2026, 11, 1) }

  def item(**attrs) = build(:pillbox_plan_item, plan:, course_start_date: start, **attrs)

  def error?(attrs, attribute, kind) = item(**attrs).tap(&:validate).errors.of_kind?(attribute, kind)

  it 'takes a source of order, catalog or manual entry', :aggregate_failures do
    expect(%w[order catalog manual].map { item(source: it) }).to all(be_valid)
    expect(error?({ source: 'pharmacy' }, :source, :inclusion)).to be(true)
  end

  describe 'goods' do
    it 'takes a SKU of the catalog, shown or not', :aggregate_failures do
      expect(item(source: 'catalog', goods: create(:catalog_goods))).to be_valid
      expect(item(source: 'catalog', goods: create(:catalog_goods, hidden: true))).to be_valid
    end

    it 'does not check the source against the SKU' do
      expect(item(source: 'manual', goods: create(:catalog_goods))).to be_valid
    end

    it 'refuses a SKU the catalog does not have', :aggregate_failures do
      expect(error?({ goods_id: 0 }, :goods_id, :invalid)).to be(true)
      expect(error?({ goods_id: -1 }, :goods_id, :invalid)).to be(true)
    end
  end

  it 'takes no name, or a name and a dosage within their lengths', :aggregate_failures do
    expect(item(name: nil, dosage: nil)).to be_valid
    expect(error?({ name: 'а' * 256 }, :name, :too_long)).to be(true)
    expect(error?({ dosage: 'а' * 101 }, :dosage, :too_long)).to be(true)
  end

  describe 'every_n' do
    it 'repeats every 1 to 99 units, every 1 by default', :aggregate_failures do
      expect(build(:pillbox_plan_item).every_n).to eq(1)
      expect([ 1, 99 ].map { item(every_n: it) }).to all(be_valid)
    end

    it 'refuses anything else', :aggregate_failures do
      expect(error?({ every_n: 0 }, :every_n, :in)).to be(true)
      expect(error?({ every_n: 100 }, :every_n, :in)).to be(true)
      expect(error?({ every_n: 'abc' }, :every_n, :not_a_number)).to be(true)
    end
  end

  describe 'weekdays' do
    it 'refuses a day out of 0 to 6', :aggregate_failures do
      expect(error?({ every_unit: 'week', weekdays: [ 7 ] }, :weekdays, :invalid)).to be(true)
      expect(error?({ every_unit: 'week', weekdays: [ -1 ] }, :weekdays, :invalid)).to be(true)
      expect(error?({ every_unit: 'week', weekdays: [ '1' ] }, :weekdays, :invalid)).to be(true)
    end
  end

  describe 'times' do
    it 'keeps one to six times sorted', :aggregate_failures do
      expect(item(times: %w[20:00 08:00]).tap(&:validate).times).to eq(%w[08:00 20:00])
      expect(item(times: %w[00:00 04:00 08:00 12:00 16:00 23:59])).to be_valid
    end

    it 'refuses no time, more than six, a repeated one and a wrong format', :aggregate_failures do
      expect(error?({ times: [] }, :times, :blank)).to be(true)
      expect(error?({ times: %w[01:00 02:00 03:00 04:00 05:00 06:00 07:00] }, :times, :too_many)).to be(true)
      expect(error?({ times: %w[08:00 08:00] }, :times, :repeated)).to be(true)
      %w[8:00 24:00 08:60].each { expect(error?({ times: [ it ] }, :times, :invalid)).to be(true) }
    end
  end

  it 'reminds once by default or until marked', :aggregate_failures do
    expect(build(:pillbox_plan_item).reminder_mode).to eq('once')
    expect(item(reminder_mode: 'until_marked')).to be_valid
    expect(error?({ reminder_mode: 'always' }, :reminder_mode, :inclusion)).to be(true)
  end

  describe 'course' do
    it 'takes 1 to 365 days', :aggregate_failures do
      expect([ 1, 365 ].map { item(course_mode: 'days', course_days: it) }).to all(be_valid)
      expect(error?({ course_mode: 'days', course_days: 0 }, :course_days, :in)).to be(true)
      expect(error?({ course_mode: 'days', course_days: 366 }, :course_days, :in)).to be(true)
      expect(error?({ course_mode: 'days', course_days: nil }, :course_days, :not_a_number)).to be(true)
    end

    it 'ends a course until a date from the start to 365 days after it', :aggregate_failures do
      expect([ start, start + 365 ].map { item(course_mode: 'until', course_end_date: it) }).to all(be_valid)
      expect(error?({ course_mode: 'until', course_end_date: nil }, :course_end_date, :blank)).to be(true)
      expect(error?({ course_mode: 'until', course_end_date: start - 1 }, :course_end_date, :before_start_date))
        .to be(true)
      expect(error?({ course_mode: 'until', course_end_date: start + 366 }, :course_end_date, :too_far)).to be(true)
    end

    it 'needs a mode' do
      expect(error?({ course_mode: nil }, :course_mode, :inclusion)).to be(true)
    end
  end

  it 'needs a unit of the schedule' do
    expect(error?({ every_unit: 'year' }, :every_unit, :inclusion)).to be(true)
  end

  it 'starts at schedule version 1' do
    expect(create(:pillbox_plan_item).schedule_version).to eq(1)
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
