# frozen_string_literal: true

# Every change works from now: what is due before it stays as it was, and reminders of the old schedule are dropped by
# the version of the schedule.
class Pillbox::Plans::Update
  PLAN_ATTRIBUTES = %i[title items_attributes].freeze

  def self.call(plan, attributes:, now: Time.current) = new(plan, now).call(attributes)

  def initialize(plan, now)
    @plan = plan
    @now = now
  end

  def call(attributes)
    @plan.assign_attributes(attributes.slice(*PLAN_ATTRIBUTES))
    @last_position = @plan.items.select(&:persisted?).map(&:position).max || -1
    planned = @plan.items.filter_map { apply(it) }
    saved = @plan.save
    Pillbox::Reminders::TopUp.call(planned, @now) if saved && @plan.active?
    # Read again by the scope, without the items discarded by this save.
    @plan.items.reset if saved
    @plan
  end

  private

  # Answers the item when its reminders are to be planned anew.
  def apply(item)
    if item.new_record?
      start(item)
    elsif item.discard
      discard(item)
    elsif item.changed.intersect?(Pillbox::PlanItem::SCHEDULE_ATTRIBUTES)
      restart(item)
    end
  end

  def start(item)
    item.position = @last_position += 1 unless item.position_came_from_user?
    item.start!(@plan.today, @now)
  end

  def discard(item)
    close(item)
    item.discarded_at = @now
    nil
  end

  def restart(item)
    period_changed = item.changed.intersect?(Pillbox::PlanItem::PERIOD_ATTRIBUTES)
    close(item)
    item.schedule_version += 1
    today = @plan.today
    item.anchor_date = today if period_changed && today
    item.normalize!
  end

  # Times before now are no longer due under the old rules. H24N-3458 writes the missed ones up to now − 1 hour here
  # before the mark moves.
  def close(item)
    item.missed_until = @now
  end
end
