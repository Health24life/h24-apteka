# frozen_string_literal: true

# The settings of the partner API, the catalog sync and the search are declared on their classes with defaults and
# types; here they take their values from the environment, and an unset variable keeps the default. They are built again
# after every code reload, as the modules that hold them are reloaded too, and are frozen once built.
Rails.application.config.to_prepare do
  Pharmapoint.config = Pharmapoint::Config.new.configure do |config|
    connection = config.connection
    connection.base_url = ENV.fetch('PHARMAPOINT_BASE_URL', connection.base_url)
    connection.api_key = ENV.fetch('PHARMAPOINT_API_KEY', connection.api_key)
    connection.domain_name = ENV.fetch('PHARMAPOINT_DOMAIN_NAME', connection.domain_name)
    config.rate_limit.per_minute = ENV.fetch('PHARMAPOINT_RATE_LIMIT_PER_MINUTE', config.rate_limit.per_minute)
    config.goods_groups_per_page = ENV.fetch('PHARMAPOINT_GOODS_GROUPS_PER_PAGE', config.goods_groups_per_page)

    search = config.search
    search.open_timeout = ENV.fetch('PHARMAPOINT_SEARCH_OPEN_TIMEOUT', search.open_timeout)
    search.read_timeout = ENV.fetch('PHARMAPOINT_SEARCH_READ_TIMEOUT', search.read_timeout)
    search.per_page = ENV.fetch('PHARMAPOINT_SEARCH_PER_PAGE', search.per_page)
    search.rate_limit_per_minute = ENV.fetch('PHARMAPOINT_SEARCH_RATE_LIMIT_PER_MINUTE', search.rate_limit_per_minute)

    cart = config.cart
    cart.open_timeout = ENV.fetch('PHARMAPOINT_CART_OPEN_TIMEOUT', cart.open_timeout)
    cart.read_timeout = ENV.fetch('PHARMAPOINT_CART_READ_TIMEOUT', cart.read_timeout)
    cart.rate_limit_per_minute = ENV.fetch('PHARMAPOINT_CART_RATE_LIMIT_PER_MINUTE', cart.rate_limit_per_minute)

    booking = config.booking
    booking.open_timeout = ENV.fetch('PHARMAPOINT_BOOKING_OPEN_TIMEOUT', booking.open_timeout)
    booking.read_timeout = ENV.fetch('PHARMAPOINT_BOOKING_READ_TIMEOUT', booking.read_timeout)

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

Rails.application.config.to_prepare do
  Catalog::Search.config = Catalog::Search::Config.new.configure do |config|
    config.providers = ENV.fetch('CATALOG_SEARCH_PROVIDERS', config.providers)
    config.max_queries = ENV.fetch('CATALOG_SEARCH_MAX_QUERIES', config.max_queries)
    config.deadline = ENV.fetch('CATALOG_SEARCH_DEADLINE', config.deadline)

    location = config.location
    location.latitude = ENV.fetch('APTEKA_SEARCH_DEFAULT_LATITUDE', location.latitude)
    location.longitude = ENV.fetch('APTEKA_SEARCH_DEFAULT_LONGITUDE', location.longitude)
    location.radius = ENV.fetch('APTEKA_SEARCH_RADIUS', location.radius)
    location.max_radius = ENV.fetch('APTEKA_SEARCH_MAX_RADIUS', location.max_radius)
  end.finalize!
end

Rails.application.config.to_prepare do
  Orders::Carts.config = Orders::Carts::Config.new.configure do |config|
    config.guest_ttl_days = ENV.fetch('APTEKA_GUEST_CART_TTL_DAYS', config.guest_ttl_days)
  end.finalize!
end

Rails.application.config.to_prepare do
  Orders::Bookings.config = Orders::Bookings::Config.new.configure do |config|
    config.drugstore_ids = ENV.fetch('APTEKA_BOOKING_DRUGSTORE_IDS', config.drugstore_ids)
    config.status_stale_minutes = ENV.fetch('APTEKA_BOOKING_STATUS_STALE_MINUTES', config.status_stale_minutes)
    config.status_poll_days = ENV.fetch('APTEKA_BOOKING_STATUS_POLL_DAYS', config.status_poll_days)
    config.final_statuses = ENV.fetch('APTEKA_BOOKING_FINAL_STATUSES', config.final_statuses)
    config.history_per_page = ENV.fetch('APTEKA_ORDERS_PER_PAGE', config.history_per_page)
    config.history_max_per_page = ENV.fetch('APTEKA_ORDERS_MAX_PER_PAGE', config.history_max_per_page)
  end.finalize!
end
