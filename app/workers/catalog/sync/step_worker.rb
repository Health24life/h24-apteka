# frozen_string_literal: true

# One step of a pass. The lock holds the step in the queue once, and lets the same step be queued again from inside
# itself, which is how a step waits for the provider's request limit.
class Catalog::Sync::StepWorker < ApplicationWorker
  RETRIES = 5

  sidekiq_options retry: RETRIES, lock: :until_and_while_executing, on_conflict: { client: :log, server: :reschedule }

  sidekiq_retry_in { |count, _error| (count**4) + 15 }
  sidekiq_retries_exhausted { |job, error| Catalog::Sync::StepRunner.give_up(*job['args'], error) }

  def perform(run_id, cursor)
    Catalog::Sync::StepRunner.call(run_id, cursor)
  rescue Pharmapoint::RateLimited => e
    self.class.perform_in(e.retry_after, run_id, cursor)
  end
end
