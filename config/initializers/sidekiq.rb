# frozen_string_literal: true

redis_url = ENV.fetch('SIDEKIQ_REDIS_URL')

Sidekiq.configure_server { it.redis = { url: redis_url } }
Sidekiq.configure_client { it.redis = { url: redis_url } }
