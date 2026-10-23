# frozen_string_literal: true

class Pillbox::Plans::Create
  PLAN_ATTRIBUTES = %i[title timezone start_date source_order_id items_attributes].freeze

  def self.call(user_id:, attributes:, now: Time.current) = new(user_id, now).call(attributes)

  def initialize(user_id, now)
    @user_id = user_id
    @now = now
  end

  def call(attributes)
    plan = Pillbox::Plan.new(attributes.slice(*PLAN_ATTRIBUTES).merge(user_id: @user_id))
    plan.start_date ||= plan.today if plan.start_date_before_type_cast.blank?
    plan.items.each_with_index { |item, index| prepare_item(item, plan.start_date, index) }
    Pillbox::Reminders::TopUp.call(plan.items, @now) if plan.save
    plan
  end

  private

  def prepare_item(item, start, index)
    item.position = index unless item.position_came_from_user?
    item.assign_attributes(user_id: @user_id, course_start_date: start, anchor_date: start, missed_until: @now)
    item.normalize!
  end
end
