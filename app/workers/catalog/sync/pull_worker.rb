# frozen_string_literal: true

# Fetches one record on demand. The lock keeps one fetch of a record in the queue, and holds through the retries,
# so the same record is not fetched twice at once; the user does not matter for that, only the record.
class Catalog::Sync::PullWorker < ApplicationWorker
  RETRIES = 3
  LOCK_TTL = 10.minutes.to_i

  sidekiq_options retry: RETRIES, lock: :until_executed, lock_ttl: LOCK_TTL, on_conflict: :log,
                  lock_args_method: :lock_args

  sidekiq_retry_in { |count, error| error.is_a?(Pharmapoint::RateLimited) ? error.retry_after : (count**4) + 15 }

  def self.lock_args(args) = args.first(2)

  def perform(type, external_id, user_id = nil)
    Catalog::Sync::PullRunner.call(type, external_id, user_id:)
  end
end
