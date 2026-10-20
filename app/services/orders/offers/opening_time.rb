# frozen_string_literal: true

# When a drugstore that is closed now opens next, as a moment and not a bare time, so that the front can tell today
# from another day: today, if today's hours have not begun yet, or else on the next day of its week schedule that has
# hours. Today's hours are the provider's live ones, or the schedule's when the provider told none. The schedule is
# read from Monday. Nothing for a drugstore open now, one the provider told nothing of, or one closed within today's
# hours, as for a break: when it opens again is not known.
class Orders::Offers::OpeningTime
  DAYS = 7
  HOURS = /\A(\d{1,2}):(\d{2})/

  def self.call(offer, week_hours, now: Time.current) = new(offer, week_hours, now).call

  def initialize(offer, week_hours, now)
    @offer = offer
    @week_hours = week_hours
    @now = now
  end

  def call
    return unless @offer.open_now == false

    from, to = today_hours
    return from if from && from > @now
    return if to && to > @now

    next_day_opening
  end

  private

  def today_hours
    from = at(@now, @offer.opens_at)
    return scheduled(@now) unless from

    [ from, closing(from, at(@now, @offer.closes_at)) ]
  end

  def next_day_opening
    (1..DAYS).each do |ahead|
      from, = scheduled(@now + ahead.days)
      return from if from
    end
    nil
  end

  def scheduled(day)
    return [] if @week_hours.size != DAYS

    text = @week_hours[(day.wday - 1) % DAYS]
    return [] unless text

    from_text, to_text = text.split('-', 2)
    from = at(day, from_text)
    from ? [ from, closing(from, at(day, to_text)) ] : []
  end

  # Hours past midnight close on the next day.
  def closing(from, to) = to && to <= from ? to + 1.day : to

  def at(day, text)
    match = HOURS.match(text.to_s.strip)
    return unless match

    hour = match[1].to_i
    minute = match[2].to_i
    return unless hour <= 24 && minute < 60

    day.beginning_of_day + hour.hours + minute.minutes
  end
end
