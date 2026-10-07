# frozen_string_literal: true

class Pharmapoint::LogCleanupWorker < ApplicationWorker
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform = Pharmapoint::LogRetention.call
end
