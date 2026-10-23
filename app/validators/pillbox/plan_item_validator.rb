# frozen_string_literal: true

class Pillbox::PlanItemValidator < ActiveModel::Validator
  def validate(item)
    goods_in_catalog(item)
    times_count_valid(item)
    times_valid(item)
    weekdays_valid(item)
    course_end_in_range(item) if item.term_until?
    course_end_not_in_past(item) if course_changed?(item)
  end

  private

  def goods_in_catalog(item)
    goods_id = item.goods_id
    item.errors.add(:goods_id, :invalid) unless goods_id.nil? || Catalog::Goods.exists?(goods_id)
  end

  def times_count_valid(item)
    times = item.times
    max = Pillbox::PlanItem::MAX_TIMES
    item.errors.add(:times, :blank) if times.empty?
    item.errors.add(:times, :too_many, count: max) if times.size > max
  end

  def times_valid(item)
    times = item.times
    item.errors.add(:times, :invalid) unless times.all? { it.match?(Pillbox::PlanItem::TIME_FORMAT) }
    item.errors.add(:times, :repeated) if times.uniq.size != times.size
  end

  def weekdays_valid(item)
    valid = item.weekdays.all? { it.is_a?(Integer) && Pillbox::PlanItem::WEEKDAYS.cover?(it) }
    item.errors.add(:weekdays, :invalid) unless valid
  end

  def course_end_in_range(item)
    start = item.course_start_date
    last = item.course_end_date
    return unless start && last

    if last < start
      item.errors.add(:course_end_date, :before_start_date)
    elsif last > start + Pillbox::PlanItem::MAX_COURSE_END
      item.errors.add(:course_end_date, :too_far, count: Pillbox::PlanItem::MAX_COURSE_END)
    end
  end

  # A change of a saved course works from now, so the course may not end before today; a new item starts today.
  def course_changed?(item)
    item.persisted? && !item.term_open? && item.changed.intersect?(%w[course_mode course_days course_end_date])
  end

  def course_end_not_in_past(item)
    last = item.course_end_date
    today = item.plan.today
    return unless last && today && last < today

    item.errors.add(item.term_days? ? :course_days : :course_end_date, :in_past)
  end
end
