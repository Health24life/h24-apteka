# frozen_string_literal: true

# One pass over a kind of the provider's data, as the sync journal sees it: counts, failures, cursor and the end.
class Catalog::Sync::RunTracker
  attr_reader :run

  # Starts a run unless the same kind is already running. A run that has hung longer than the allowed time is
  # closed as failed first, so a crashed worker does not block the kind for good.
  def self.start(provider:, kind:, config: Pharmapoint::Config.current)
    running = SyncRun.excluding_pulls.where(provider:, kind:, status: 'running')
    running.where(started_at: ...config.stale_run_after.ago).find_each do |stale|
      new(stale).fail!('The run did not finish in time and was closed by the next start')
    end
    return if running.exists?

    open_run(provider, kind, 'full')
  end

  # A short run for records fetched on demand; it never blocks and is never blocked by a run.
  def self.pull(provider:, kind:)
    open_run(provider, kind, 'pull')
  end

  # `new` and `save!` rather than `create!`, which the type signatures say may answer with a list of records.
  def self.open_run(provider, kind, mode)
    run = SyncRun.new(provider:, kind:, started_at: Time.current, progress: { 'mode' => mode })
    run.save!
    new(run)
  end

  def initialize(run)
    @run = run
  end

  delegate :running?, to: :run

  def processed!(count = 1)
    SyncRun.update_counters(run.id, processed_count: count) # rubocop:disable Rails/SkipsModelValidations -- an atomic counter
  end

  # Runs the block for one record. A failure is written to the journal and the record keeps its earlier version;
  # the rest of the run goes on.
  def guard(entity_type, external_id, payload = nil)
    yield
  rescue StandardError => e
    record_failure(entity_type, external_id, e, payload)
    nil
  end

  def record_failure(entity_type, external_id, error, payload = nil)
    masker = Pharmapoint::Logging::Masker.new
    run.failures.create!(entity_type:, external_id: external_id.to_s, error_class: error.class.name,
                         message: masker.text(error.message), payload: masker.body(payload&.as_json))
  end

  def advance(cursor) = update_progress('cursor' => cursor)

  def update_progress(values)
    run.update!(progress: run.progress.merge(values))
  end

  # A page the provider would not give is a gap in the pass: the run goes on, but it no longer covers everything.
  def page_failed!(cursor, error)
    record_failure('page', cursor || 'all', error)
    update_progress('partial' => true)
  end

  def partial? = run.progress['partial'] == true

  def finish!
    run.reload
    status = run.failed_count.positive? || partial? ? 'completed_with_failures' : 'succeeded'
    run.update!(status:, finished_at: Time.current)
  end

  def fail!(message)
    run.update!(status: 'failed', finished_at: Time.current, error_message: Pharmapoint::Logging::Masker.new.text(message))
  end
end
