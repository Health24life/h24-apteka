# frozen_string_literal: true

# Removes the runs of on-demand fetches that outlived their period, with their failures; the live search makes one for
# every group it brings, so they would pile up. The recurring runs are kept. It deletes in batches, so it does not hold
# the journal while fetches write to it.
class Catalog::Sync::PullRunRetention
  BATCH = 1000

  # The failures go with their run through the foreign key.
  def self.call(config: Pharmapoint::Config.current, now: Time.current)
    SyncRun.mode_eq('pull').where(started_at: ...(now - config.pull_run_retention)).in_batches(of: BATCH).delete_all
  end
end
