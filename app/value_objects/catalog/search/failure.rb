# frozen_string_literal: true

# A provider that gave no answer: it is unavailable, or its request limit is used up for `retry_after` seconds.
class Catalog::Search::Failure < Data.define(:provider, :reason, :retry_after)
  def rate_limited? = reason == :rate_limited
end
