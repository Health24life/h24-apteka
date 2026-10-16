# frozen_string_literal: true

# The settings of the partner API and of the catalog sync are declared on their classes with defaults and types; here
# they take their values from the environment, and an unset variable keeps the default. They are built again after
# every code reload, as the modules that hold them are reloaded too, and are frozen once built.
Rails.application.config.to_prepare do
  Pharmapoint.config = Pharmapoint::Config.new.configure do |config|
    connection = config.connection
    connection.base_url = ENV.fetch('PHARMAPOINT_BASE_URL', connection.base_url)
    connection.api_key = ENV.fetch('PHARMAPOINT_API_KEY', connection.api_key)
    connection.domain_name = ENV.fetch('PHARMAPOINT_DOMAIN_NAME', connection.domain_name)
    config.rate_limit.per_minute = ENV.fetch('PHARMAPOINT_RATE_LIMIT_PER_MINUTE', config.rate_limit.per_minute)
    config.goods_groups_per_page = ENV.fetch('PHARMAPOINT_GOODS_GROUPS_PER_PAGE', config.goods_groups_per_page)

    retention = config.log_retention_days
    retention.booking = ENV.fetch('PHARMAPOINT_LOG_RETENTION_BOOKING_DAYS', retention.booking)
    retention.search = ENV.fetch('PHARMAPOINT_LOG_RETENTION_SEARCH_DAYS', retention.search)
    retention.refresh = ENV.fetch('PHARMAPOINT_LOG_RETENTION_REFRESH_DAYS', retention.refresh)
    retention.other = ENV.fetch('PHARMAPOINT_LOG_RETENTION_OTHER_DAYS', retention.other)
  end.finalize!
end

Rails.application.config.to_prepare do
  Catalog::Sync.config = Catalog::Sync::Config.new.configure do |config|
    config.search_points = ENV.fetch('PHARMAPOINT_DRUGSTORE_SEARCH_POINTS', config.search_points)

    pull = config.pull
    pull.stash_ttl = ENV.fetch('CATALOG_SYNC_STASH_TTL', pull.stash_ttl)
    pull.cooldown = ENV.fetch('CATALOG_SYNC_PULL_COOLDOWN', pull.cooldown)
    pull.run_retention = ENV.fetch('SYNC_PULL_RUN_RETENTION_DAYS', pull.run_retention)
  end.finalize!
end
