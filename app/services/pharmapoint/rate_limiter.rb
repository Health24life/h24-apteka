# frozen_string_literal: true

# Keeps every worker within the partner's request limit. State lives in Redis, so it is shared by all processes.
class Pharmapoint::RateLimiter
  KEY = 'pharmapoint:rate_limit'
  MINUTE = 60

  def initialize(config: Pharmapoint::Config.current, clock: Time)
    @config = config
    @clock = clock
  end

  # Raises RateLimited when the partner asked us to wait or our own per-minute budget is spent.
  def guard!
    now = @clock.now.to_i
    wait = blocked_for(now)
    raise Pharmapoint::RateLimited, wait if wait.positive?

    wait = spend(now)
    raise Pharmapoint::RateLimited, wait if wait.positive?
  end

  # The partner reports what is left of its limit on every answer; nothing left means wait for the window.
  def record(headers)
    remaining = Integer(headers['x-ratelimit-remaining'], exception: false)
    block!(@config.rate_limit_window) if remaining&.zero?
  end

  def block!(seconds)
    redis { it.call('SET', "#{KEY}:blocked_until", (@clock.now.to_i + seconds).to_s, 'EX', seconds) }
  end

  private

  def blocked_for(now)
    until_time = redis { it.call('GET', "#{KEY}:blocked_until") }.to_i
    [ until_time - now, 0 ].max
  end

  # Counts a request in the current minute; returns the seconds to wait when the minute's budget is already spent.
  def spend(now)
    window = now / MINUTE
    key = "#{KEY}:window:#{window}"
    used = redis do |connection|
      connection.pipelined do |pipeline|
        pipeline.call('INCR', key)
        pipeline.call('EXPIRE', key, MINUTE * 2)
      end.first
    end
    used.to_i > @config.rate_limit_per_minute ? ((window + 1) * MINUTE) - now : 0
  end

  def redis(&) = Sidekiq.redis(&)
end
