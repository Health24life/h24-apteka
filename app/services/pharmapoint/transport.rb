# frozen_string_literal: true

# One call to the partner API: paced against the request limit, logged, checked and read as JSON. A call with a body is
# sent as a POST of JSON, any other as a GET.
class Pharmapoint::Transport
  ERROR_BODY_LIMIT = 500

  def initialize(config:, rate_limiter:, masker:, logger:)
    @config = config
    @rate_limiter = rate_limiter
    @masker = masker
    @logger = logger
  end

  # The key is checked first: a call that cannot be sent does not spend the request limit.
  def call(path, params = {}, body: nil, share: nil, timeouts: nil)
    credentials = @config.credentials!
    @rate_limiter.guard!(share:)
    response = request(path, params, body, credentials, timeouts)
    @rate_limiter.record(response.headers)
    check_status!(response)
    yield parse(response.body)
  rescue Pharmapoint::InvalidResponse
    @logger.mark_invalid_response!
    raise
  end

  private

  def request(path, params, body, credentials, timeouts)
    api_key, domain_name = credentials
    connection = connection(api_key, domain_name, timeouts)
    return connection.get(path, params) unless body

    url = params.empty? ? path : "#{path}?#{params.to_query}"
    connection.post(url, JSON.generate(body), 'Content-Type' => 'application/json')
  rescue Faraday::Error => e
    raise Pharmapoint::TransientError, @masker.text(e.message)
  end

  # Only a successful answer is read as JSON: an error page of a gateway has no reason to be.
  def parse(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError => e
    raise Pharmapoint::InvalidResponse, @masker.text(e.message)
  end

  def check_status!(response)
    status = response.status
    return if status.between?(200, 299)

    message = "Pharmapoint answered #{status}: #{@masker.text(response.body.to_s).first(ERROR_BODY_LIMIT)}"
    raise rate_limited(response) if status == 429
    raise Pharmapoint::TransientError, message if status >= 500

    raise Pharmapoint::PermanentError.new(message, status:)
  end

  def rate_limited(response)
    wait = Integer(response.headers['retry-after'], exception: false) || @config.rate_limit.window
    @rate_limiter.block!(wait)
    Pharmapoint::RateLimited.new(wait)
  end

  def connection(api_key, domain_name, timeouts = nil)
    settings = @config.connection
    Faraday.new(
      url: settings.base_url,
      headers: {
        'API-Key' => api_key,
        'Domain-Name' => domain_name,
        'Accept' => 'application/json'
      },
      request: timeouts || { open_timeout: settings.open_timeout, timeout: settings.read_timeout }
    ) do |faraday|
      faraday.use Pharmapoint::Logging::Middleware, logger: @logger
      faraday.adapter :typhoeus
    end
  end
end
