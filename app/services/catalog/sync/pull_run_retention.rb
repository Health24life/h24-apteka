# frozen_string_literal: true

# Removes the runs of on-demand fetches that outlived their period, with their failures; the live search makes one for
# every group it brings, so they would pile up. The recurring runs are kept. It deletes in batches, so it does not hold
# the journal while fetches write to it.
class Catalog::Sync::PullRunRetention
  BATCH = 1000

  def self.call(config: Pharmapoint::Config.current, now: Time.current)
    cutoff = now - config.pull_run_retention
    removed = 0
    loop do
      ids = SyncRun.mode_eq('pull').where(started_at: ...cutoff).limit(BATCH).pluck(:id)
      break if ids.empty?

      # The failures go with their run through the foreign key.
      removed += SyncRun.where(id: ids).delete_all
    end
    removed
  end
end
