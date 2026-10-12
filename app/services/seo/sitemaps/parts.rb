# frozen_string_literal: true

# Writes the URLs of one kind of page into as many sitemap files as it takes, each within the protocol's limit.
class Seo::Sitemaps::Parts
  class Part < Data.define(:name, :changed_at); end

  LIMIT = 50_000
  NAMESPACE = 'http://www.sitemaps.org/schemas/sitemap/0.9'

  def initialize(dir, kind, limit: LIMIT)
    @dir = dir
    @kind = kind
    @limit = limit
    @parts = []
    @count = 0
  end

  def add(url, changed_at)
    start_part if @file.nil? || @count == @limit
    file = @file or return
    file.write("<url><loc>#{CGI.escapeHTML(url)}</loc>#{lastmod(changed_at)}</url>\n")
    @count += 1
    @changed_at = [ @changed_at, changed_at ].compact.max
  end

  # Closes the last file and returns every part written, with the latest change of the pages in it.
  def finish
    close_part
    @parts
  end

  private

  def start_part
    close_part
    name = "sitemap-#{@kind}-#{@parts.size + 1}.xml"
    file = @dir.join(name).open('w')
    file.write(%(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="#{NAMESPACE}">\n))
    @name = name
    @file = file
    @count = 0
    @changed_at = nil
  end

  def close_part
    file = @file or return
    file.write("</urlset>\n")
    file.close
    @parts << Part.new(name: @name.to_s, changed_at: @changed_at)
    @file = nil
  end

  def lastmod(changed_at) = changed_at ? "<lastmod>#{changed_at.utc.iso8601}</lastmod>" : ''
end
