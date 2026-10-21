# frozen_string_literal: true

class Catalog::Sync::PullRunCleanupWorker < ApplicationWorker
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform = Catalog::Sync::Pulls::Retention.call
end
