# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Active Admin's Tailwind source (app/assets/tailwind/active_admin.css) contains a raw
# `@import "tailwindcss"` and must NOT be served by Propshaft — only the compiled
# app/assets/builds/active_admin.css (built by `rails active_admin:build`) is.
Rails.application.config.assets.excluded_paths << Rails.root.join('app/assets/tailwind')
