# frozen_string_literal: true

# Writes the sitemap of the section with sitemap_generator: an index and gzipped parts of categories and products,
# the home page and the static pages first. The front proxies the index and the parts from the storage at its own
# host, as the protocol allows only URLs of the sitemap's host. Files are written in place, so a run that breaks off
# may leave old and new parts side by side until the next one; parts the new index no longer lists are removed after
# it.
class Seo::Sitemaps::Refresh
  INDEX = 'sitemap.xml.gz'

  # The generator fills these in by default; a sitemap carries only the real date of change.
  NO_DEFAULTS = { lastmod: nil, priority: nil, changefreq: nil }.freeze

  def self.call(config: Seo::Config.current) = new(config).call

  def initialize(config)
    @paths = Seo::Pages::Path.new(config)
    @storage = Seo::Sitemaps::Storage.for(config)
  end

  # Returns the names of the files the index lists.
  def call
    sitemap.create { |sitemap| fill(sitemap) }
    parts = listed_parts
    @storage.prune(parts + [ INDEX ])
    parts
  ensure
    @storage.cleanup
  end

  private

  def sitemap
    SitemapGenerator::LinkSet.new(
      default_host: "#{@paths.url('')}/", sitemaps_host: "#{@paths.url(@paths.prefix)}/", sitemaps_path: Seo::Sitemaps::Storage::PREFIX,
      public_path: @storage.public_path, adapter: @storage.adapter, filename: :sitemap, create_index: true,
      include_root: false, include_index: false, verbose: false, yield_sitemap: true
    )
  end

  def fill(sitemap)
    sitemap.group(filename: :categories) do |group|
      group.add(@paths.home, **NO_DEFAULTS) if Seo::Sitemaps::Entries.home?
      Seo::Sitemaps::Entries.static_pages { |slug, at| group.add(@paths.static(slug), **NO_DEFAULTS, lastmod: at) }
      Seo::Sitemaps::Entries.categories { |slug, at| group.add(@paths.category(slug), **NO_DEFAULTS, lastmod: at) }
    end
    sitemap.group(filename: :goods) do |group|
      Seo::Sitemaps::Entries.goods { |slug, at| group.add(@paths.goods(slug), **NO_DEFAULTS, lastmod: at) }
    end
  end

  def listed_parts
    path = File.join(@storage.public_path, Seo::Sitemaps::Storage::PREFIX, INDEX)
    index = Zlib.gunzip(File.binread(path)).force_encoding(Encoding::UTF_8)
    index.scan(%r{<loc>([^<]+)</loc>}).flatten.map { File.basename(it) }
  end
end
