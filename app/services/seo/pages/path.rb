# frozen_string_literal: true

# Builds the paths of the front's pages. The front's routes must match these segments: the backend recognises a page,
# builds breadcrumbs, redirects and the sitemap by them. Changing one after publication needs redirects of its own.
class Seo::Pages::Path
  SEGMENTS = { category: 'katalog', goods: 'tovar', filter: 'dobirka', cart: 'cart', order: 'order' }.freeze

  def initialize(config = Seo::Config.current)
    @config = config
  end

  def home = prefix.presence || '/'

  def cart = "#{prefix}/#{SEGMENTS.fetch(:cart)}"

  def order(number) = "#{prefix}/#{SEGMENTS.fetch(:order)}/#{number}"

  def category(slug) = "#{prefix}/#{SEGMENTS.fetch(:category)}/#{slug}"

  def goods(slug) = "#{prefix}/#{SEGMENTS.fetch(:goods)}/#{slug}"

  def filter(slug) = "#{prefix}/#{SEGMENTS.fetch(:filter)}/#{slug}"

  def static(slug) = "#{prefix}/#{slug}"

  def record(record)
    case record
    when Catalog::Goods then goods(record.slug)
    when Catalog::Category then category(record.slug)
    when Seo::Filter then filter(record.slug)
    when Seo::StaticPage then record.home? ? home : static(record.slug)
    end
  end

  # A path with its query, in the order the parameters are given.
  def with_query(path, params) = params.empty? ? path : "#{path}?#{URI.encode_www_form(params)}"

  # The front's full URL of a path: the path already carries the section prefix.
  def url(path)
    origin = URI.parse(@config.front_base_url!)
    origin.path = ''
    "#{origin}#{path}"
  end

  # A path inside the section, without the section prefix: the home page of a prefixed section is the empty path.
  def relative(path) = prefix.empty? ? path : path.delete_prefix(prefix)

  def prefix = @config.front_path_prefix
end
