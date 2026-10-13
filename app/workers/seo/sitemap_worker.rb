# frozen_string_literal: true

# One generation runs and one more may wait behind it; any further request merges with the waiting one.
class Seo::SitemapWorker < ApplicationWorker
  sidekiq_options lock: :until_and_while_executing, on_conflict: { client: :log, server: :reschedule }

  # A missing setting is not fixed by waiting: the job goes straight to the dead set instead of retrying for days.
  sidekiq_retry_in { |_count, error| :kill if error.is_a?(Seo::Config::MissingSetting) }

  def perform = Seo::Sitemaps::Refresh.call
end
