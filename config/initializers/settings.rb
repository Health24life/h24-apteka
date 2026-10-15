# frozen_string_literal: true

# The settings of the partner API and of the catalog sync are declared on their classes with defaults and types; here
# they take their values from the environment, and an unset or empty variable keeps the default. They are built again
# after every code reload, as the modules that hold them are reloaded too, and are frozen once built.
Rails.application.config.to_prepare do
  from_env = lambda do |settings, variables|
    values = variables.filter_map { |name, variable| [ name, ENV.fetch(variable) ] if ENV[variable].present? }
    settings.update(values.to_h)
  end

  Pharmapoint.config = Pharmapoint::Config.new.configure do |config|
    from_env.call(config.connection, base_url: 'PHARMAPOINT_BASE_URL', api_key: 'PHARMAPOINT_API_KEY',
                                     domain_name: 'PHARMAPOINT_DOMAIN_NAME')
    from_env.call(config.rate_limit, per_minute: 'PHARMAPOINT_RATE_LIMIT_PER_MINUTE')
    from_env.call(config, goods_groups_per_page: 'PHARMAPOINT_GOODS_GROUPS_PER_PAGE')
    from_env.call(config.log_retention_days, booking: 'PHARMAPOINT_LOG_RETENTION_BOOKING_DAYS',
                                             search: 'PHARMAPOINT_LOG_RETENTION_SEARCH_DAYS',
                                             refresh: 'PHARMAPOINT_LOG_RETENTION_REFRESH_DAYS',
                                             other: 'PHARMAPOINT_LOG_RETENTION_OTHER_DAYS')
  end.finalize!

  Catalog::Sync.config = Catalog::Sync::Config.new.configure do |config|
    from_env.call(config, search_points: 'PHARMAPOINT_DRUGSTORE_SEARCH_POINTS')
    from_env.call(config.pull, stash_ttl: 'CATALOG_SYNC_STASH_TTL', cooldown: 'CATALOG_SYNC_PULL_COOLDOWN',
                               run_retention: 'SYNC_PULL_RUN_RETENTION_DAYS')
  end.finalize!
end
