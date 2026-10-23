# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pillbox::Plan do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:h24_core_user) }

  def plan(**attrs) = build(:pillbox_plan, user:, **attrs)

  def item(**attrs) = build(:pillbox_plan_item, plan: nil, user_id: user.id, **attrs)

  it 'keeps the title without the spaces around it' do
    expect(plan(title: '  Застуда  ').title).to eq('Застуда')
  end

  it 'needs a title that is not only spaces', :aggregate_failures do
    expect(plan(title: '   ').tap(&:validate).errors.of_kind?(:title, :blank)).to be(true)
    expect(plan(title: nil).tap(&:validate).errors.of_kind?(:title, :blank)).to be(true)
  end

  it 'takes a title of up to 50 characters', :aggregate_failures do
    expect(plan(title: 'а' * 50)).to be_valid
    expect(plan(title: 'а' * 51).tap(&:validate).errors.of_kind?(:title, :too_long)).to be(true)
  end

  it 'needs an IANA time zone', :aggregate_failures do
    expect(plan(timezone: 'Europe/Warsaw')).to be_valid
    %w[Kyiv abc].push(nil).each do |timezone|
      expect(plan(timezone:).tap(&:validate).errors.of_kind?(:timezone, :inclusion)).to be(true)
    end
  end

  it 'needs a user the core has' do
    expect(build(:pillbox_plan, user: nil, user_id: 0)).not_to be_valid
  end

  describe 'items' do
    it 'needs at least one' do
      expect(plan(items: []).tap(&:validate).errors.of_kind?(:items, :blank)).to be(true)
    end

    it 'takes up to ten', :aggregate_failures do
      expect(plan(items: Array.new(10) { item })).to be_valid
      expect(plan(items: Array.new(11) { item }).tap(&:validate).errors.of_kind?(:items, :too_many)).to be(true)
    end

    it 'names the errors of an item by its place in the items attributes' do
      attributes = { source: 'manual', every_unit: 'day', course_mode: 'open' }
      record = plan(items: [], items_attributes: [ attributes.merge(times: %w[08:00]), attributes.merge(times: []) ])

      record.validate

      expect(record.errors.of_kind?(:'items[1].times', :blank)).to be(true)
    end

    it 'names the errors of a saved plan by the place in the items attributes, not in the plan' do
      record = create(:pillbox_plan, user:, items: [ item(name: 'A'), item(name: 'B') ])
      second = record.items.second

      record.assign_attributes(items_attributes: [ { id: second.id, times: [] } ])
      record.validate

      expect(record.errors.of_kind?(:'items[0].times', :blank)).to be(true)
    end

    it 'does not count items discarded by the same save' do
      record = create(:pillbox_plan, user:)
      record.items.each { it.discarded_at = Time.current }

      expect(record.tap(&:validate).errors.of_kind?(:items, :blank)).to be(true)
    end

    it 'counts the items already in a plan towards the limit' do
      record = create(:pillbox_plan, user:, items: Array.new(10) { item })
      record.items.build(attributes_for(:pillbox_plan_item).except(:plan))

      expect(record.tap(&:validate).errors.of_kind?(:items, :too_many)).to be(true)
    end

    it 'lists the items still in the plan by their position' do
      record = create(:pillbox_plan, user:, items: [ item(position: 1, name: 'B'), item(position: 0, name: 'A') ])
      create(:pillbox_plan_item, plan: record, position: 2, discarded_at: Time.current)

      expect(record.reload.items.map(&:name)).to eq(%w[A B])
    end
  end

  describe 'limit of open plans' do
    it 'refuses a sixth active or paused plan' do
      create_list(:pillbox_plan, 4, user:)
      create(:pillbox_plan, user:, status: 'paused')

      expect(plan.tap(&:validate).errors.of_kind?(:base, :too_many_plans)).to be(true)
    end

    it 'does not count completed plans or plans of other users' do
      create_list(:pillbox_plan, 4, user:)
      create_list(:pillbox_plan, 2, user:, status: 'completed')
      create(:pillbox_plan)

      expect(plan).to be_valid
    end
  end

  describe 'start date' do
    # 2026-11-01 00:30 in Kyiv is still 2026-10-31 in UTC.
    around { travel_to(Time.utc(2026, 10, 31, 22, 30), &it) }

    it 'takes today in the time zone of the plan', :aggregate_failures do
      expect(plan.today).to eq(Date.new(2026, 11, 1))
      expect(plan(start_date: Date.new(2026, 11, 1))).to be_valid
    end

    it 'refuses a day before today in the time zone of the plan' do
      record = plan(start_date: Date.new(2026, 10, 31))

      expect(record.tap(&:validate).errors.of_kind?(:start_date, :in_past)).to be(true)
    end
  end

  describe 'source order' do
    it 'takes a booking of the user' do
      order = create(:order, :sent, user_id: user.id)

      expect(plan(source_order_id: order.id)).to be_valid
    end

    it 'refuses a cart, a booking of someone else or of a guest, and an order that is not there', :aggregate_failures do
      [
        create(:order, user_id: user.id).id,
        create(:order, :sent, user_id: create(:h24_core_user).id).id,
        create(:order, :sent).id,
        0
      ].each do |source_order_id|
        expect(plan(source_order_id:).tap(&:validate).errors.of_kind?(:source_order_id, :invalid)).to be(true)
      end
    end
  end

  it 'is active when created' do
    expect(create(:pillbox_plan).status).to eq('active')
  end
end

# == Schema Information
#
# Table name: pillbox_plans
#
#  id              :bigint           not null, primary key
#  completed_at    :datetime
#  missed_days     :integer          default(0), not null
#  paused_at       :datetime
#  status          :string           default("active"), not null
#  timezone        :string           not null
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  source_order_id :bigint
#  user_id         :integer          not null
#
# Indexes
#
#  index_pillbox_plans_on_source_order_id  (source_order_id)
#  index_pillbox_plans_on_timezone         (timezone)
#  index_pillbox_plans_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (source_order_id => orders.id) ON DELETE => nullify
#
