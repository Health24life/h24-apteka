# frozen_string_literal: true

# Opens a run over one kind of the provider's data and queues its first step, unless that kind is already running.
class Catalog::Sync::Starter
  def self.call(kind)
    tracker = Catalog::Sync::RunTracker.start(provider: Catalog::Sync.provider, kind:)
    return unless tracker

    Catalog::Sync::StepWorker.perform_async(tracker.run.id, Catalog::Sync::Importers.for(kind).first_cursor)
  end
end
