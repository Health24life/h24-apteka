# frozen_string_literal: true

# Base of the background workers. They are native Sidekiq workers rather than Active Job jobs, because
# sidekiq-unique-jobs does not support Active Job. A worker only calls a service; the logic lives there.
class ApplicationWorker
  include Sidekiq::Job
  # sidekiq-status records a job only when its class includes this module.
  include Sidekiq::Status::Worker

  sidekiq_options queue: 'default'
end
