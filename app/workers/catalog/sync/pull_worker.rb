# frozen_string_literal: true

# Fetches one record on demand. The lock keeps one fetch of a record of a provider in the queue, and holds through the
# retries, so the same record is not fetched twice at once; the user and the stash do not matter for that.
class Catalog::Sync::PullWorker < ApplicationWorker
  # Enough to outlast a few windows of the provider's request limit.
  RETRIES = 8
  BACKOFF = ->(count) { (count**4) + 15 }
  # Covers every retry with Sidekiq's own jitter, so the lock does not drop while the fetch still waits for a try.
  LOCK_TTL = ((0...RETRIES).sum { BACKOFF.call(it) } + 30.minutes).to_i

  sidekiq_options retry: RETRIES,
                  lock: :until_executed,
                  lock_ttl: LOCK_TTL,
                  on_conflict: :log,
                  lock_args_method: :lock_args

  sidekiq_retry_in { |count, error| error.is_a?(Pharmapoint::RateLimited) ? error.retry_after : BACKOFF.call(count) }
  sidekiq_retries_exhausted { |job, error| Catalog::Sync::Pulls::Runner.give_up(error, *job['args'].first(4)) }

  def self.lock_args(args) = [ args[0], args[1], args[3] ]

  def perform(type, external_id, user_id = nil, provider_id = nil, stash_key = nil)
    Catalog::Sync::Pulls::Runner.call(type, external_id, user_id:, provider_id:, stash_key:)
  end
end
