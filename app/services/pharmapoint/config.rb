# frozen_string_literal: true

# Connection, load and log settings of the partner API, declared with their defaults and types. The values come from the
# environment in config/initializers/settings.rb, which keeps the frozen result as Pharmapoint.config; a spec builds its
# own with `Pharmapoint::Config.new.configure`.
class Pharmapoint::Config
  include Dry::Configurable

  DEFAULT_BASE_URL = 'https://pharmapoint.ua/api/v1/online-drugstore'
  # Request headers whose value never reaches a log.
  SECRET_HEADERS = %w[api-key customer-phone authorization cookie].freeze
  # Keys of a request or response body that hold a client's phone number or the code that redeems a prescription.
  SECRET_BODY_KEYS = %w[customer_phone_number repayment_code].freeze
  INTEGER = ->(value) { Integer(value) }
  # An empty value in the environment means none.
  PRESENT = ->(value) { value.presence }

  setting :connection, reader: true do
    setting :base_url, default: DEFAULT_BASE_URL
    setting :api_key, constructor: PRESENT
    setting :domain_name, constructor: PRESENT
    setting :open_timeout, default: 5, constructor: INTEGER
    setting :read_timeout, default: 30, constructor: INTEGER
  end

  setting :rate_limit, reader: true do
    setting :per_minute, default: 60, constructor: INTEGER
    # Seconds to wait when the partner reports nothing left and names no wait of its own.
    setting :window, default: 60, constructor: INTEGER
  end

  setting :goods_groups_per_page, default: 50, constructor: INTEGER, reader: true

  # Days a request log entry is kept, per category of the log.
  setting :log_retention_days, reader: true do
    setting :booking, default: 14, constructor: INTEGER
    setting :search, default: 1, constructor: INTEGER
    setting :refresh, default: 7, constructor: INTEGER
    setting :other, default: 7, constructor: INTEGER
  end

  # The key and the domain name are required to call the partner; a missing one stops the call before it is sent.
  def credentials!
    api_key = connection.api_key
    domain_name = connection.domain_name
    raise Pharmapoint::ConfigurationError, 'PHARMAPOINT_API_KEY is not set' if api_key.blank?
    raise Pharmapoint::ConfigurationError, 'PHARMAPOINT_DOMAIN_NAME is not set' if domain_name.blank?

    [ api_key.to_s, domain_name.to_s ]
  end

  # A category the log does not know is kept as long as the other ones.
  def retention_for(category)
    log_retention_days.to_h.fetch(category.to_sym) { log_retention_days.other }.days
  end
end
