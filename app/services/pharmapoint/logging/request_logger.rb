# frozen_string_literal: true

# Writes one entry of the provider request log per attempt. A failed write is reported and never reaches the caller.
class Pharmapoint::Logging::RequestLogger
  class Entry < Data.define(:http_method, :path, :query, :request_headers, :request_body, :response_status,
                            :response_headers, :response_body, :outcome, :error_class, :duration_ms)
  end

  # rubocop:disable-next Metrics/ParameterLists -- the context of one client: who asked, why, and which attempt it is.
  def initialize(provider:, category:, user_id:, sync_run:, attempt:, masker: Pharmapoint::Logging::Masker.new)
    @provider = provider
    @category = category
    @user_id = user_id
    @sync_run = sync_run
    @attempt = attempt
    @masker = masker
  end

  def record(entry)
    log = Provider::RequestLog.new(context.merge(attributes_of(entry)))
    log.save!
    @last = log
  rescue StandardError => e
    @last = nil
    Rails.error.report(e, handled: true, context: { source: 'provider_request_log' })
  end

  # The body was well-formed JSON, but the reader found it lacking what it needs.
  def mark_invalid_response!
    @last&.update!(outcome: 'invalid_response')
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { source: 'provider_request_log' })
  end

  private

  def context
    { provider: @provider, sync_run: @sync_run, user_id: @user_id, category: @category.to_s, attempt: @attempt }
  end

  # Secrets are masked here, before anything is written.
  def attributes_of(entry)
    { http_method: entry.http_method, path: entry.path, query: @masker.body(entry.query),
      request_headers: @masker.headers(entry.request_headers), request_body: @masker.body(entry.request_body),
      response_headers: @masker.headers(entry.response_headers), response_body: @masker.body(entry.response_body),
      response_status: entry.response_status, outcome: entry.outcome, error_class: entry.error_class,
      duration_ms: entry.duration_ms }
  end
end
