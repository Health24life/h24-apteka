# frozen_string_literal: true

# Faraday middleware that reports every attempt, answered or not, to the request logger.
class Pharmapoint::Logging::Middleware < Faraday::Middleware
  class Result < Data.define(:status, :headers, :body, :outcome, :error_class); end

  def initialize(app, logger:, clock: Process)
    super(app)
    @logger = logger
    @clock = clock
  end

  def call(env)
    started = @clock.clock_gettime(Process::CLOCK_MONOTONIC)
    failure = nil
    @app.call(env)
  rescue Faraday::Error => e
    failure = e
    raise
  ensure
    @logger.record(entry(env, failure, elapsed_ms(started)))
  end

  private

  def elapsed_ms(started) = ((@clock.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

  def entry(env, error, duration)
    result = error ? failed(error) : answered(env)
    Pharmapoint::Logging::RequestLogger::Entry.new(**request_part(env), **response_part(result), duration_ms: duration)
  end

  def request_part(env)
    { http_method: env.method.to_s.upcase, path: env.url.path.to_s, query: query_of(env),
      request_headers: env.request_headers, request_body: json_value(env.request_body) }
  end

  def response_part(result)
    { response_status: result.status, response_headers: result.headers, response_body: result.body,
      outcome: result.outcome, error_class: result.error_class }
  end

  def query_of(env) = Faraday::Utils.parse_nested_query(env.url.query) || {}

  # No raise-on-status middleware is used, so an exception means nothing came back, whatever the adapter left in the
  # env.
  def failed(error)
    outcome = error.is_a?(Faraday::TimeoutError) ? 'timeout' : 'connection_error'
    Result.new(status: nil, headers: {}, body: nil, outcome:, error_class: error.class.name)
  end

  # Some adapters report status 0 when nothing came back, which is no answer either.
  def answered(env)
    status = env.status.to_i
    unless status.positive?
      return Result.new(status: nil, headers: {}, body: nil, outcome: 'connection_error',
                        error_class: nil)
    end

    body = json_value(env.body)
    Result.new(status:, headers: env.response_headers || {}, body:, outcome: outcome_of(status, body), error_class: nil)
  end

  def outcome_of(status, body)
    return 'http_error' unless status.between?(200, 299)

    body.is_a?(Hash) || body.is_a?(Array) ? 'success' : 'invalid_response'
  end

  # A body that is not JSON is kept as the text received, which jsonb stores as a JSON string.
  def json_value(body)
    return if body.nil? || body == ''
    return body unless body.is_a?(String)

    JSON.parse(body)
  rescue JSON::ParserError
    body
  end
end
