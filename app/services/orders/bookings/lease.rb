# frozen_string_literal: true

# A short claim in Redis that every process sees: one booking of a token at a time, and one live ask for the status of
# an order in a while. A claim that is never given back expires on its own.
module Orders::Bookings::Lease
  PREFIX = 'orders_bookings_lease'
  # Frees the claim only while it is still this holder's, so one that expired and was taken again stays.
  RELEASE = <<~LUA
    if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) end
    return 0
  LUA

  # Truthy when the claim was taken; it is not given back and lasts the seconds given.
  def self.take(name, seconds, holder = '1')
    Sidekiq.redis { |redis| redis.call('SET', key(name), holder, 'NX', 'EX', seconds) }
  end

  # The block's value, run while the claim is held and given back after; nil without running it when it is held.
  def self.hold(name, seconds)
    holder = SecureRandom.uuid
    return unless take(name, seconds, holder)

    begin
      yield
    ensure
      Sidekiq.redis { |redis| redis.call('EVAL', RELEASE, 1, key(name), holder) }
    end
  end

  def self.key(name) = "#{PREFIX}:#{name}"
end
