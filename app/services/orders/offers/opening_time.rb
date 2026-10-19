# frozen_string_literal: true

# When a drugstore that is closed now opens next: today, if the provider's hours for today have not begun yet, or else
# on the next day of its week schedule that has hours. The schedule is read from Monday. Nothing for a drugstore open
# now or one the provider told nothing of.
class Orders::Offers::OpeningTime
  DAYS = 7

  def self.call(offer, week_hours, now: Time.current) = new(offer, week_hours, now).call

  def initialize(offer, week_hours, now)
    @offer = offer
    @week_hours = week_hours
    @now = now
  end

  def call
    return unless @offer.open_now == false

    today = @offer.opens_at
    return today if today && today > @now.strftime('%H:%M')

    next_day_opening
  end

  private

  def next_day_opening
    return if @week_hours.size != DAYS

    monday_based = (@now.wday - 1) % DAYS
    (1..DAYS).each do |ahead|
      start = @week_hours[(monday_based + ahead) % DAYS].to_s[/\A\d{2}:\d{2}/]
      return start if start
    end
    nil
  end
end
