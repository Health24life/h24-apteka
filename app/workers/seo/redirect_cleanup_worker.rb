# frozen_string_literal: true

class Seo::RedirectCleanupWorker < ApplicationWorker
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform = Seo::Redirects::Cleanup.call
end
