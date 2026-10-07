# frozen_string_literal: true

# Starts a pass over one kind of the provider's data, as the schedule asks. A second start of the same kind waits
# in no queue: it is dropped while the first one has not run yet.
class Catalog::Sync::StartWorker < ApplicationWorker
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform(kind) = Catalog::Sync::Starter.call(kind)
end
