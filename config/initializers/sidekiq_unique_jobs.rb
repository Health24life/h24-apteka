# frozen_string_literal: true

# Uniqueness of the workers that ask for a lock. It is off in tests, where nothing runs through Redis queues; the
# specs that check the lock turn it on for their own duration.
SidekiqUniqueJobs.configure do |config|
  config.enabled = !Rails.env.test?
  config.logger_enabled = !Rails.env.test?
end
