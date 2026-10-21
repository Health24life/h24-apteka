# frozen_string_literal: true

# Reads the queries of a search request as the front sent them: an array of one to the configured number of queries,
# each with a text, a page and a place. A value that cannot be searched raises Invalid with the code that names it, so
# nothing is asked of the providers.
class Catalog::Search::Queries::Build
  TEXT_LENGTH = 3..100
  PAGES = 1..50
  LATITUDE_LIMIT = 90
  LONGITUDE_LIMIT = 180

  def self.call(queries, config: Catalog::Search.config) = new(config).call(queries)

  def initialize(config)
    @config = config
  end

  def call(queries)
    invalid!(:invalid_search_queries) unless queries.is_a?(Array) && queries.size.between?(1, @config.max_queries)

    queries.map { query(it) }
  end

  private

  def query(value)
    invalid!(:invalid_search_queries) unless value.is_a?(Hash)

    Catalog::Search::Query.new(
      text: text(value['text']),
      page: page(value['page']),
      location: location(value['location'])
    )
  end

  def text(value)
    text = value.is_a?(String) ? value.squish : ''
    invalid!(:invalid_search_text) unless TEXT_LENGTH.cover?(text.length)

    text
  end

  def page(value)
    return 1 if value.nil?

    invalid!(:invalid_search_page) unless value.is_a?(Integer) && PAGES.cover?(value)

    value
  end

  def location(value)
    return Catalog::Search::Location.around(config: @config) if value.nil?

    invalid!(:invalid_search_location) unless value.is_a?(Hash)

    latitude = coordinate(value['latitude'], LATITUDE_LIMIT)
    longitude = coordinate(value['longitude'], LONGITUDE_LIMIT)
    invalid!(:invalid_search_location) if latitude.nil? != longitude.nil?

    Catalog::Search::Location.around(latitude:, longitude:, radius: radius(value['radius']), config: @config)
  end

  def coordinate(value, limit)
    return if value.nil?

    invalid!(:invalid_search_location) unless value.is_a?(Numeric) && value.abs <= limit

    value.to_f
  end

  def radius(value)
    return if value.nil?

    invalid!(:invalid_search_location) unless value.is_a?(Integer) && value.between?(1, @config.location.max_radius)

    value
  end

  def invalid!(code) = raise(Catalog::Search::Invalid, code)
end
