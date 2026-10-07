# frozen_string_literal: true

# Connection, load and log settings of the partner API. They come from the environment, so changing one needs no code.
class Pharmapoint::Config
  class Point < Data.define(:latitude, :longitude, :radius); end

  DEFAULT_BASE_URL = 'https://pharmapoint.ua/api/v1/online-drugstore'
  RETENTION_DAYS = { 'booking' => 14, 'search' => 1, 'refresh' => 7, 'other' => 7 }.freeze
  # Request headers whose value never reaches a log.
  SECRET_HEADERS = %w[api-key customer-phone authorization cookie].freeze
  # Keys of a request or response body that hold a client's phone number.
  SECRET_BODY_KEYS = %w[customer_phone].freeze
  DEFAULTS = {
    base_url: DEFAULT_BASE_URL, api_key: nil, domain_name: nil, rate_limit_per_minute: 60, rate_limit_window: 60,
    open_timeout: 5, read_timeout: 30, goods_groups_per_page: 50, search_points: nil,
    stale_run_after: 6.hours, stale_record_after: 1.day, retention_days: RETENTION_DAYS
  }.freeze

  attr_reader(*DEFAULTS.keys - [ :search_points ])

  def self.current = @current ||= from_env

  def self.reset! = @current = nil

  def self.from_env(env = ENV)
    new(
      base_url: env.fetch('PHARMAPOINT_BASE_URL', nil).presence || DEFAULT_BASE_URL,
      api_key: env.fetch('PHARMAPOINT_API_KEY', nil).presence,
      domain_name: env.fetch('PHARMAPOINT_DOMAIN_NAME', nil).presence,
      rate_limit_per_minute: Integer(env.fetch('PHARMAPOINT_RATE_LIMIT_PER_MINUTE', 60)),
      goods_groups_per_page: Integer(env.fetch('PHARMAPOINT_GOODS_GROUPS_PER_PAGE', 50)),
      search_points: parse_points(env.fetch('PHARMAPOINT_DRUGSTORE_SEARCH_POINTS', nil)),
      retention_days: parse_retention(env)
    )
  end

  def self.parse_points(json)
    return [] if json.blank?

    JSON.parse(json).map do |point|
      Point.new(latitude: Float(point.fetch('latitude')), longitude: Float(point.fetch('longitude')),
                radius: Integer(point.fetch('radius')))
    end
  end

  def self.parse_retention(env)
    RETENTION_DAYS.to_h do |category, default|
      [ category, Integer(env.fetch("PHARMAPOINT_LOG_RETENTION_#{category.upcase}_DAYS", default)) ]
    end
  end

  # Every setting has a default, so a caller names only what differs.
  def initialize(**settings)
    settings.assert_valid_keys(*DEFAULTS.keys)
    DEFAULTS.merge(settings).each { |name, value| instance_variable_set(:"@#{name}", value) }
  end

  def search_points = @search_points || []

  # The key and the domain name are required to call the partner; a missing one stops the call before it is sent.
  def credentials!
    raise Pharmapoint::ConfigurationError, 'PHARMAPOINT_API_KEY is not set' if api_key.blank?
    raise Pharmapoint::ConfigurationError, 'PHARMAPOINT_DOMAIN_NAME is not set' if domain_name.blank?

    [ api_key.to_s, domain_name.to_s ]
  end

  def retention_for(category) = retention_days.fetch(category.to_s) { retention_days.fetch('other') }.days
end
