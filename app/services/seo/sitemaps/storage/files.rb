# frozen_string_literal: true

# The sitemap in a directory. Mounted as public/ of the web pods, it is served as static files at /sitemaps/.
class Seo::Sitemaps::Storage::Files
  def initialize(config)
    @root = Rails.root.join(config.sitemap_dir!)
  end

  def public_path = @root.to_s

  def adapter = SitemapGenerator::FileAdapter.new

  # Removes the files of the earlier runs that the new index no longer lists.
  def prune(keep)
    @root.join(Seo::Sitemaps::Storage::PREFIX).glob('*').each { it.delete unless keep.include?(it.basename.to_s) }
  end
end
