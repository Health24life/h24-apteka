# frozen_string_literal: true

namespace :seo do
  namespace :redirects do
    desc 'Refill the Redis cache of the SEO redirects from the table, e.g. after Redis lost its keys'
    task rebuild_cache: :environment do
      puts "cached redirects: #{Seo::Redirects::Cache.rebuild}"
    end
  end
end
