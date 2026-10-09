# frozen_string_literal: true

redis_url = ENV.fetch('SIDEKIQ_REDIS_URL')
status_expiration = 3.hours.to_i

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
    chain.add SidekiqMiddleware::JobAttempt
  end
  # Jobs enqueued from inside other jobs need the client middleware on the server as well.
  config.client_middleware { |chain| chain.add SidekiqUniqueJobs::Middleware::Client }
  SidekiqUniqueJobs::Server.configure(config)
  # The partner integration's jobs are built in code, as their cron expressions come from the environment.
  config.on(:startup) do
    Sidekiq::Cron::Job.load_from_hash!(Pharmapoint::Schedule.jobs, source: Pharmapoint::Schedule::SOURCE)
  end
  Sidekiq::Status.configure_server_middleware(config, expiration: status_expiration)
  Sidekiq::Status.configure_client_middleware(config, expiration: status_expiration)
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
  config.client_middleware { |chain| chain.add SidekiqUniqueJobs::Middleware::Client }
  Sidekiq::Status.configure_client_middleware(config, expiration: status_expiration)
end
