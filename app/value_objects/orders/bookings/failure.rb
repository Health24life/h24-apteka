# frozen_string_literal: true

# A provider that did not take or give an order: it is unavailable, refused the request, or its request limit is used
# up for `retry_after` seconds.
class Orders::Bookings::Failure < Data.define(:reason, :retry_after)
  def rate_limited? = reason == :rate_limited
end
