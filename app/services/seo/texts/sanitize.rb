# frozen_string_literal: true

# Keeps of an HTML text only the tags the front shows: paragraphs, headings, lists, quotes, bold, italics and links.
# Other tags go and their text stays, but scripts, styles and embedded frames go with what is inside them. A link
# keeps its address only when it is a path of the section or a site over HTTPS.
class Seo::Texts::Sanitize
  TAGS = %w[p br h2 h3 ul ol li blockquote strong em a].freeze
  ATTRIBUTES = %w[href].freeze
  PRUNED = %w[script style iframe object embed template noscript].freeze
  LINK = %r{\A(?:/(?!/)|https://)}i

  class Result < Data.define(:html, :changed); end

  def self.call(html)
    return Result.new(html:, changed: false) if html.blank?

    clean = with_safe_links(sanitizer.sanitize(pruned(html), tags: TAGS, attributes: ATTRIBUTES))
    Result.new(html: clean, changed: clean != Nokogiri::HTML5.fragment(html).to_html)
  end

  def self.pruned(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css(PRUNED.join(', ')).each(&:remove)
    fragment.to_html
  end

  def self.with_safe_links(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css('a[href]').each { it.remove_attribute('href') unless it['href'].to_s.strip.match?(LINK) }
    fragment.to_html
  end

  def self.sanitizer = @sanitizer ||= Rails::HTML5::SafeListSanitizer.new

  private_class_method :pruned, :with_safe_links, :sanitizer
end
