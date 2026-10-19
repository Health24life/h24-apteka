# frozen_string_literal: true

class Orders::Carts::AbandonedCleanupWorker < ApplicationWorker
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform = Orders::Carts::RemoveAbandoned.call
end
