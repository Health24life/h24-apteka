# frozen_string_literal: true

# The partner API: the client, its readers, the request log and the limits it works within.
module Pharmapoint
  class Error < StandardError; end

  # The key or another required setting is missing: nothing is sent to the partner.
  class ConfigurationError < Error; end

  # Worth trying again later: network, timeout, 429 and 5xx.
  class TransientError < Error; end

  # The partner refused the request (4xx other than 429); repeating it would give the same answer.
  class PermanentError < Error
    attr_reader :status

    def initialize(message, status:)
      super(message)
      @status = status
    end
  end

  # The partner answered 2xx but the body cannot be read or lacks the expected structure.
  class InvalidResponse < Error; end

  # The request limit is used up; try again after `retry_after` seconds.
  class RateLimited < TransientError
    attr_reader :retry_after

    def initialize(retry_after)
      super("Pharmapoint request limit reached, retry in #{retry_after}s")
      @retry_after = retry_after
    end
  end
end
