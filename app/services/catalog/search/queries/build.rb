# frozen_string_literal: true

# Reads the queries of a search request as the front sent them: an array of one to the configured number of queries,
# each with a text, a page and a place. A value that cannot be searched raises Invalid with the code that names it, so
# nothing is asked of the providers.
class Catalog::Search::Queries::Build
  TEXT_LENGTH = 3..100
  PAGES = 1..50

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

  def location(value) = Catalog::Search::Locations::Build.call(value, code: :invalid_search_location, config: @config)

  def invalid!(code) = raise(Catalog::Search::Invalid, code)
end
