# frozen_string_literal: true

source 'https://rubygems.org'

ruby '4.0.7'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.1.4'
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'
gem 'redis', '~> 5.0'
# Background jobs behind Active Job; Redis endpoint from SIDEKIQ_REDIS_URL. [https://sidekiq.org]
gem 'sidekiq', '~> 8.1'
# Cron-style recurring jobs, loaded from config/schedule.yml; managed from the Sidekiq Web "Cron" tab.
# [https://github.com/sidekiq-cron/sidekiq-cron]
gem 'sidekiq-cron', '~> 2.4'
# Keeps failed jobs (after retries are exhausted) browsable in a Sidekiq Web "Failures" tab.
# [https://github.com/mhfs/sidekiq-failures]
gem 'sidekiq-failures', '~> 1.1'
# Per-job status/progress tracking (Sidekiq::Status), with a Sidekiq Web "Statuses" tab.
# [https://github.com/kenaniah/sidekiq-status]
gem 'sidekiq-status', '~> 4.0'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Admin framework — v4 beta required for Rails 8.1 + Propshaft [https://activeadmin.info]
gem 'activeadmin', '4.0.0.beta23'
# Searchable/AJAX select boxes for ActiveAdmin filters & forms, via Tom Select (vanilla JS, no jQuery —
# the classic activeadmin-searchable_select is jQuery/Select2 and pinned to activeadmin < 4). [https://github.com/rs-pro/activeadmin-tom_select]
gem 'activeadmin-tom_select'
# Per-action authorization for the admin panel, via ActiveAdmin's built-in PunditAdapter. Policies live in app/policies.
gem 'pundit'
# Authentication backing ActiveAdmin's AdminUser model [https://github.com/heartcombo/devise]
gem 'devise'
# Standalone Tailwind CSS CLI binary (no Node) to build ActiveAdmin's stylesheet.
# Using tailwindcss-ruby (binary only) rather than tailwindcss-rails so it does not
# hook a whole-app `tailwindcss:build` into assets:precompile. [https://github.com/flavorjones/tailwindcss-ruby]
gem 'tailwindcss-ruby'
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem 'image_processing', '~> 1.2'

gem 'ostruct', '~> 0.6'
gem 'rswag-api', '2.17.0'
gem 'rswag-ui', '2.17.0'

gem 'globalize', '~> 7.1'
gem 'globalize-accessors', '0.3.0'
gem 'uklatn', '~> 1.20'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem 'bundler-audit', require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  gem 'dotenv-rails', '>= 3.2.0'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  gem 'annotaterb'

  # RBS type signatures in sig/: rbs itself, rbs_rails for models and path helpers,
  # steep to type-check app/ against them. [https://github.com/ruby/rbs]
  gem 'rbs', '~> 4.2', require: false
  gem 'rbs_rails', '~> 0.13', require: false
  gem 'steep', '~> 2.1', require: false
end

group :test do
  gem 'factory_bot_rails', '>= 5.2.0'
  gem 'rspec-rails', '~> 6.1'
  gem 'rswag-specs', '2.17.0'
  gem 'shoulda-matchers'
end

source 'https://rs.health24.dev/private' do
  gem 'h24_auth', '0.1.1'

  group :development, :test do
    gem 'health24_rubocop_config', '1.0.0', require: false
  end
end
