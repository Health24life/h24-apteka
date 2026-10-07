# frozen_string_literal: true

# Sidekiq does not tell a worker which attempt it is on; this server middleware remembers it for the running job, so
# the request log can say which attempt a request belongs to.
class JobAttempt
  KEY = :job_attempt

  def self.current = Thread.current[KEY] || 1

  def call(_worker, job, _queue)
    # A job that has not failed yet has no retry count; the first retry has count 0.
    Thread.current[KEY] = job.key?('retry_count') ? job['retry_count'].to_i + 2 : 1
    yield
  ensure
    Thread.current[KEY] = nil
  end
end
