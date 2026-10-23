# frozen_string_literal: true

# Called by the services that write items, not on every validation: what follows from the schedule the client sent.
class Pillbox::PlanItems::Normalize
  def self.call(item) = new(item).call

  def initialize(item)
    @item = item
  end

  def call
    @item.weekdays = @item.every_week? ? weekdays : []
    derive_course
    @item
  end

  private

  def weekdays
    days = Array(@item.weekdays).uniq
    days.all?(Integer) ? days.sort : days
  end

  def derive_course
    start = @item.course_start_date
    if @item.term_open?
      @item.course_days = nil
      @item.course_end_date = nil
    elsif start
      derive_course_from(start)
    end
  end

  def derive_course_from(start)
    days = @item.course_days
    last = @item.course_end_date
    if @item.term_days? && days
      @item.course_end_date = start + (days - 1)
    elsif @item.term_until? && last
      @item.course_days = (last - start).to_i + 1
    end
  end
end
