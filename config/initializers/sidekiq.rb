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
  Sidekiq::Status.configure_server_middleware(config, expiration: status_expiration)
  Sidekiq::Status.configure_client_middleware(config, expiration: status_expiration)
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
  config.client_middleware { |chain| chain.add SidekiqUniqueJobs::Middleware::Client }
  Sidekiq::Status.configure_client_middleware(config, expiration: status_expiration)
end
