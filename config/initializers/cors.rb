# frozen_string_literal: true

# The section's browser front calls the API from its own domains only (CORS_ORIGINS, space-separated; empty lets no
# browser origin in). No cookies cross: the API reads the session from the Authorization header. The mobile app sends
# no Origin and is not affected.
Rails.application.config.x.cors_origins = ENV.fetch('CORS_ORIGINS', '').split

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins { |source, _env| Rails.application.config.x.cors_origins.include?(source) }
    resource '/api/*', headers: :any, methods: %i[get post put patch delete options head], credentials: false
  end
end
