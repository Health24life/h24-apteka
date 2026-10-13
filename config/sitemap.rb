# frozen_string_literal: true

# Read by the rake tasks of sitemap_generator: `rake sitemap:refresh:no_ping` writes the sitemap by hand, as the
# scheduled job does.
Seo::Sitemaps::Refresh.call
