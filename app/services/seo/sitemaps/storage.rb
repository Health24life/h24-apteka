# frozen_string_literal: true

# Where the generated sitemap is kept, chosen by `SEO_SITEMAP_STORAGE`: a directory (a volume) or an S3 bucket. Either
# way the files keep the same names from run to run, so the front can proxy them by fixed paths.
module Seo::Sitemaps::Storage
  PREFIX = 'sitemaps/'

  def self.for(config) = config.sitemap_storage! == 's3' ? Bucket.new(config.sitemap_s3!) : Files.new(config)
end
