# frozen_string_literal: true

# One generation runs and one more may wait behind it; any further request merges with the waiting one.
class Seo::SitemapWorker < ApplicationWorker
  sidekiq_options lock: :until_and_while_executing, on_conflict: { client: :log, server: :reschedule }

  def perform = Seo::Sitemaps::Generate.call
end
