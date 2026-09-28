# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # sidekiq-status records a job only when its class includes this module, despite its README's claim
  # that Active Job jobs are tracked automatically.
  include Sidekiq::Status::Worker

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
