# frozen_string_literal: true

# Reads the place a request asks about as the front sent it: latitude and longitude together, a radius in metres up to
# the configured maximum, the configured point or radius for what is left out. A place that cannot be asked about
# raises Invalid with the code the caller names.
class Catalog::Search::Locations::Build
  LATITUDE_LIMIT = 90
  LONGITUDE_LIMIT = 180

  def self.call(value, code:, config: Catalog::Search.config) = new(code, config).call(value)

  def initialize(code, config)
    @code = code
    @config = config
  end

  def call(value)
    return Catalog::Search::Location.around(config: @config) if value.nil?

    invalid! unless value.is_a?(Hash)

    latitude = coordinate(value['latitude'], LATITUDE_LIMIT)
    longitude = coordinate(value['longitude'], LONGITUDE_LIMIT)
    invalid! if latitude.nil? != longitude.nil?

    Catalog::Search::Location.around(latitude:, longitude:, radius: radius(value['radius']), config: @config)
  end

  private

  def coordinate(value, limit)
    return if value.nil?

    invalid! unless value.is_a?(Numeric) && value.abs <= limit

    value.to_f
  end

  def radius(value)
    return if value.nil?

    invalid! unless value.is_a?(Integer) && value.between?(1, @config.location.max_radius)

    value
  end

  def invalid! = raise(Catalog::Search::Invalid, @code)
end
