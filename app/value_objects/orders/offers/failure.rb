# frozen_string_literal: true

# A provider that gave no offers: it is unavailable, or its request limit is used up for `retry_after` seconds.
class Orders::Offers::Failure < Data.define(:reason, :retry_after)
  def rate_limited? = reason == :rate_limited
end
