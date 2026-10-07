# frozen_string_literal: true

# One step of a run: a page of goods groups, a search point of drugstores, or the whole of a small dictionary. A step
# the provider cannot give is a gap, not the end: the run goes on to the next step and ends partial. Errors that are
# worth another try (network, limit) are left to the worker to retry.
class Catalog::Sync::StepRunner
  # What the provider will not change its mind about; the step is lost and the run goes on.
  LOST_STEP_ERRORS = [ Pharmapoint::PermanentError, Pharmapoint::InvalidResponse ].freeze

  def self.call(run_id, cursor) = new(run_id).call(cursor)

  # The step could not be done after all the retries.
  def self.give_up(run_id, cursor, error) = new(run_id).give_up(cursor, error)

  def initialize(run_id)
    @tracker = Catalog::Sync::RunTracker.new(SyncRun.find(run_id))
  end

  def call(cursor)
    return unless @tracker.running?

    proceed(importer.call(@tracker, client, Catalog::Sync::Linker.new(@tracker.run.provider), cursor))
  rescue *LOST_STEP_ERRORS => e
    give_up(cursor, e)
  rescue Pharmapoint::ConfigurationError => e
    @tracker.fail!(e.message)
  end

  # Writes the lost step to the journal and moves on.
  def give_up(cursor, error)
    @tracker.page_failed!(cursor, error)
    proceed(importer.skip(@tracker, cursor), failed: true)
  end

  private

  def proceed(next_cursor, failed: false)
    if next_cursor
      @tracker.advance(next_cursor)
      Catalog::Sync::StepWorker.perform_async(@tracker.run.id, next_cursor)
    else
      finish(failed)
    end
  end

  # A pass of a single step that failed has nothing to its credit, so it is failed outright.
  def finish(failed)
    return @tracker.fail!('The only step of the run failed') if lost_everything?(failed)

    @tracker.finish!
    Catalog::Sync::Withdrawer.call(@tracker.run) if withdrawal_due?
  end

  def lost_everything?(failed) = failed && importer.first_cursor.nil? && @tracker.run.processed_count.zero?

  # Only a full pass that missed no page has seen all the provider has.
  def withdrawal_due? = @tracker.run.kind == 'goods_groups' && !@tracker.partial?

  def importer = Catalog::Sync::Importers.for(@tracker.run.kind)

  def client
    Pharmapoint::Client.new(provider: @tracker.run.provider, purpose: :refresh, sync_run: @tracker.run,
                            attempt: SidekiqMiddleware::JobAttempt.current)
  end
end
