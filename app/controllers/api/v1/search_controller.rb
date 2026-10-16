# frozen_string_literal: true

# The search of goods for the web and the app. It always asks the providers live and never the local catalog, so a
# provider that does not answer is an error of the search, not an empty list. A guest is served as a signed-in user is.
class Api::V1::SearchController < ApiController
  TEXT_LENGTH = 3..100
  PAGES = 1..50

  # A part of the request that cannot be searched; the code names it.
  class Invalid < StandardError
    attr_reader :code

    def initialize(code)
      super(code.to_s)
      @code = code
    end
  end

  rescue_from Invalid, with: ->(error) { render_error(error.code, status: :unprocessable_content) }

  def create
    no_store
    results = Catalog::Search::Run.call(queries, user_id: current_user_id)
    return unavailable(results) if results.all?(&:unavailable?)

    render json: Catalog::Search::ResponseBlueprint.render_as_hash({ results: })
  end

  private

  def search_config = Catalog::Search.config

  def queries
    list = params[:queries]
    raise Invalid, :invalid_search_queries unless list.is_a?(Array) && list.size.between?(1, search_config.max_queries)

    list.map { query(it) }
  end

  def query(element)
    raise Invalid, :invalid_search_queries unless element.is_a?(ActionController::Parameters)

    Catalog::Search::Query.new(
      text: text(element[:text]),
      page: page(element[:page]),
      location: location(element[:location])
    )
  end

  def text(value)
    text = value.is_a?(String) ? value.squish : ''
    raise Invalid, :invalid_search_text unless TEXT_LENGTH.cover?(text.length)

    text
  end

  def page(value)
    return 1 if value.nil?
    raise Invalid, :invalid_search_page unless value.is_a?(Integer) && PAGES.cover?(value)

    value
  end

  def location(value)
    return Catalog::Search::Location.around(config: search_config) if value.nil?
    raise Invalid, :invalid_search_location unless value.is_a?(ActionController::Parameters)

    latitude = coordinate(value[:latitude], 90)
    longitude = coordinate(value[:longitude], 180)
    raise Invalid, :invalid_search_location if latitude.nil? != longitude.nil?

    Catalog::Search::Location.around(latitude:, longitude:, radius: radius(value[:radius]), config: search_config)
  end

  def coordinate(value, limit)
    return if value.nil?
    raise Invalid, :invalid_search_location unless value.is_a?(Numeric) && value.abs <= limit

    value.to_f
  end

  def radius(value)
    return if value.nil?
    raise Invalid, :invalid_search_location unless value.is_a?(Integer) && value.between?(
      1,
      search_config.location.max_radius
    )

    value
  end

  # Every limit refusal tells when to try again, so the front may wait for the earliest one.
  def unavailable(results)
    failures = results.flat_map(&:failures)
    return render_error(:search_unavailable, status: :service_unavailable) unless
      failures.any? && failures.all?(&:rate_limited?)

    response.headers['Retry-After'] = failures.filter_map(&:retry_after).min.to_s
    render_error(:search_busy, status: :service_unavailable)
  end
end
