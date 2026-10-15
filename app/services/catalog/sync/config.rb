# frozen_string_literal: true

# Settings of the catalog sync: where the drugstore directory is gathered, when a run or a record is stale, and how the
# on-demand fetch keeps its stash, pauses and journal. The values come from the environment in
# config/initializers/settings.rb, which keeps the frozen result as Catalog::Sync.config.
class Catalog::Sync::Config
  include Dry::Configurable

  SECONDS = ->(value) { Integer(value).seconds }
  DAYS = ->(value) { Integer(value).days }

  # The environment gives the points as a JSON array of {latitude, longitude, radius}.
  def self.parse_points(value)
    list = value.is_a?(String) ? JSON.parse(value.presence || '[]') : value
    list.map do |point|
      next point if point.is_a?(Pharmapoint::SearchPoint)

      Pharmapoint::SearchPoint.new(
        latitude: Float(point.fetch('latitude')),
        longitude: Float(point.fetch('longitude')),
        radius: Integer(point.fetch('radius'))
      )
    end
  end

  setting :search_points, default: [], constructor: ->(value) { parse_points(value) }, reader: true
  # A run still going after this is taken for crashed and closed by the next start.
  setting :stale_run_after, default: 6.hours, reader: true
  # A record synced longer ago than this is fetched again when it is asked for.
  setting :stale_record_after, default: 1.day, reader: true

  setting :pull, reader: true do
    # How long a goods group found by the live search waits in the stash for its fetch.
    setting :stash_ttl, default: 600, constructor: SECONDS
    # How long a record whose fetch failed for good is not queued again.
    setting :cooldown, default: 900, constructor: SECONDS
    # How long the journal keeps the runs of on-demand fetches.
    setting :run_retention, default: 90, constructor: DAYS
  end
end
