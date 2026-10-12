# frozen_string_literal: true

# Writes the sitemap of the section: an index and parts of categories and products, the home page first. A new version
# is written next to the one being served and replaces it in one rename of a link, so a search engine never gets a
# half-written sitemap and a failed run leaves the previous version in place.
class Seo::Sitemaps::Generate
  INDEX = 'sitemap.xml'
  CURRENT = 'current'
  VERSIONS = 'versions'

  def self.call(config: Seo::Config.current) = new(config).call

  # The directory the sitemap is served from.
  def self.current_dir(config: Seo::Config.current) = Rails.root.join(config.sitemap_dir!, CURRENT)

  def initialize(config)
    @paths = Seo::Pages::Path.new(config)
    @root = Rails.root.join(config.sitemap_dir!)
  end

  # Returns the names of the parts written.
  def call
    version = @root.join(VERSIONS, Time.current.strftime('%Y%m%d%H%M%S%6N'))
    FileUtils.mkdir_p(version)
    parts = categories(version) + goods(version)
    write_index(version, parts)
    publish(version)
    parts.map(&:name)
  rescue StandardError
    FileUtils.rm_rf(version) if version
    raise
  end

  private

  def categories(version)
    parts = Seo::Sitemaps::Parts.new(version, 'categories')
    parts.add(@paths.url(@paths.home), nil)
    Seo::Sitemaps::Entries.categories { |slug, changed_at| parts.add(@paths.url(@paths.category(slug)), changed_at) }
    parts.finish
  end

  def goods(version)
    parts = Seo::Sitemaps::Parts.new(version, 'goods')
    Seo::Sitemaps::Entries.goods { |slug, changed_at| parts.add(@paths.url(@paths.goods(slug)), changed_at) }
    parts.finish
  end

  # The index lists the parts at the front host, which proxies them to the API.
  def write_index(version, parts)
    File.open(version.join(INDEX), 'w') do |file|
      file.write(%(<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="#{Seo::Sitemaps::Parts::NAMESPACE}">\n))
      parts.each do |part|
        url = CGI.escapeHTML(@paths.url("#{@paths.prefix}/#{part.name}"))
        lastmod = part.changed_at ? "<lastmod>#{part.changed_at.utc.iso8601}</lastmod>" : ''
        file.write("<sitemap><loc>#{url}</loc>#{lastmod}</sitemap>\n")
      end
      file.write("</sitemapindex>\n")
    end
  end

  # Points the served link at the new version in one rename, then removes every version but it and the previous one,
  # which a request that started before the switch may still be reading.
  def publish(version)
    link = @root.join(CURRENT)
    kept = [ version.basename, (link.readlink.basename if link.symlink?) ]
    staged = @root.join(".#{CURRENT}-#{SecureRandom.hex(4)}")
    staged.make_symlink(version.relative_path_from(@root))
    staged.rename(link)
    @root.join(VERSIONS).children.each { FileUtils.rm_rf(it) unless kept.include?(it.basename) }
  end
end
