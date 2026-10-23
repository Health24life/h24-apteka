# frozen_string_literal: true

class Pillbox::Plans::Create
  PLAN_ATTRIBUTES = %i[title timezone start_date source_order_id].freeze
  ITEM_ATTRIBUTES = %i[
    source
    goods_id
    name
    dosage
    position
    every_unit
    every_n
    weekdays
    times
    reminder_mode
    course_mode
    course_days
    course_end_date
  ].freeze

  def self.call(user_id:, attributes:, now: Time.current) = new(user_id, now).call(attributes)

  def initialize(user_id, now)
    @user_id = user_id
    @now = now
  end

  def call(attributes)
    plan = Pillbox::Plan.new(attributes.slice(*PLAN_ATTRIBUTES).merge(user_id: @user_id))
    plan.start_date ||= plan.today if plan.start_date_before_type_cast.blank?
    Array(attributes[:items]).each_with_index { |item, index| build_item(plan, item, index) }
    Pillbox::Reminders::TopUp.call(plan.items, @now) if plan.save
    plan
  end

  private

  def build_item(plan, item, index)
    start = plan.start_date
    plan.items.build(
      item.slice(*ITEM_ATTRIBUTES).merge(
        user_id: @user_id,
        position: item[:position] || index,
        course_start_date: start,
        anchor_date: start,
        missed_until: @now
      )
    ).normalize!
  end
end
