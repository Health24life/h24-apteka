# frozen_string_literal: true

# Keeps every worker within the partner's request limit. State lives in Redis, so it is shared by all processes.
class Pharmapoint::RateLimiter
  KEY = 'pharmapoint:rate_limit'
  MINUTE = 60

  # What was left of the share in its minute after the last request with a share this limiter counted; nil before one.
  attr_reader :share_left

  def initialize(config: Pharmapoint.config, clock: Time)
    @config = config
    @clock = clock
    @share_left = nil
  end

  # Raises RateLimited when the partner asked us to wait or our own per-minute budget is spent. A request with a share
  # is counted against its share first: one the share refuses does not spend the budget the others live on, and one the
  # budget refuses gives its place in the share back.
  def guard!(share: nil)
    now = @clock.now.to_i
    wait = blocked_for(now)
    raise Pharmapoint::RateLimited, wait if wait.positive?

    spend_share(now, share) if share
    used = spend(now, KEY)
    return if used <= @config.rate_limit.per_minute

    give_back(now, share) if share
    raise Pharmapoint::RateLimited, wait_for_window(now)
  end

  # The seconds to wait before a request would get through, zero when it would; nothing is spent. A worker that can
  # put its job off asks this before it opens anything it would have to close as failed.
  def wait_time
    now = @clock.now.to_i
    blocked = blocked_for(now)
    return blocked if blocked.positive?

    window = now / MINUTE
    used = redis { it.call('GET', window_key(window)) }.to_i
    used >= @config.rate_limit.per_minute ? ((window + 1) * MINUTE) - now : 0
  end

  # The partner reports what is left of its limit on every answer; nothing left means wait for the window.
  def record(headers)
    remaining = Integer(headers['x-ratelimit-remaining'], exception: false)
    block!(@config.rate_limit.window) if remaining&.zero?
  end

  def block!(seconds)
    redis { it.call('SET', "#{KEY}:blocked_until", (@clock.now.to_i + seconds).to_s, 'EX', seconds) }
  end

  private

  def blocked_for(now)
    until_time = redis { it.call('GET', "#{KEY}:blocked_until") }.to_i
    [ until_time - now, 0 ].max
  end

  # Counts a request in the current minute and returns how many the minute has counted.
  def spend(now, prefix)
    key = window_key(now / MINUTE, prefix)
    used = redis do |connection|
      connection.pipelined do |pipeline|
        pipeline.call('INCR', key)
        pipeline.call('EXPIRE', key, MINUTE * 2)
      end.first
    end
    used.to_i
  end

  def spend_share(now, share)
    limit = share_limit(share)
    used = spend(now, share_key(share))
    @share_left = [ limit - used, 0 ].max
    raise Pharmapoint::RateLimited, wait_for_window(now) if used > limit
  end

  def give_back(now, share)
    redis { it.call('DECR', window_key(now / MINUTE, share_key(share))) }
    @share_left = @share_left.to_i + 1
  end

  def wait_for_window(now) = (((now / MINUTE) + 1) * MINUTE) - now

  def window_key(window, prefix = KEY) = "#{prefix}:window:#{window}"

  def share_key(share) = "#{KEY}:#{share}"

  def share_limit(share)
    case share
    when :search then @config.search.rate_limit_per_minute
    when :cart then @config.cart.rate_limit_per_minute
    else raise ArgumentError, "Unknown share of the request limit: #{share}"
    end
  end

  def redis(&) = Sidekiq.redis(&)
end
