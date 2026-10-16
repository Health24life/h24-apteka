# frozen_string_literal: true

# Settings of the live search: which providers it asks, how many queries a request may hold, how long the request may
# take, and where it looks when the front sends no place. The values come from the environment in
# config/initializers/settings.rb, which keeps the frozen result as Catalog::Search.config.
class Catalog::Search::Config
  include Dry::Configurable

  INTEGER = ->(value) { Integer(value) }
  FLOAT = ->(value) { Float(value) }
  # A comma-separated list in the environment; an empty one turns the search off.
  CODES = ->(value) { (value.is_a?(String) ? value.split(',') : Array(value)).map { it.to_s.strip }.compact_blank }

  setting :providers, default: %w[pharmapoint], constructor: CODES, reader: true
  setting :max_queries, default: 1, constructor: INTEGER, reader: true
  # Seconds the whole request may take, all providers and queries together.
  setting :deadline, default: 4.0, constructor: FLOAT, reader: true

  setting :location, reader: true do
    setting :latitude, default: 50.4501, constructor: FLOAT
    setting :longitude, default: 30.5234, constructor: FLOAT
    # Metres.
    setting :radius, default: 25_000, constructor: INTEGER
    setting :max_radius, default: 100_000, constructor: INTEGER
  end
end
