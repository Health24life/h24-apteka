# frozen_string_literal: true

# Cloudflare Turnstile guards booking from bots, as in system_ruby. Without the keys the check is off; in development
# and tests the gem then takes the token "mocked", and in production a booking without the check is refused by the
# controller. An unreachable Cloudflare lets the request through.
RailsCloudflareTurnstile.configure do |config|
  config.site_key = ENV['CF_TURNSTILE_SITE_KEY'].presence
  config.secret_key = ENV['CF_TURNSTILE_SECRET_KEY'].presence
  config.enabled = config.site_key.present? && config.secret_key.present?
  config.fail_open = true
end
