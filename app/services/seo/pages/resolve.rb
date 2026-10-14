# frozen_string_literal: true

# Tells what a path of the front shows: a page, a permanent redirect to another path, or no page at all.
#
# Only the parameters the page understands are kept: `page` and the filters on a category. Anything else, UTM tags
# included, neither changes the answer nor reaches a redirect. A path that is not in its normal form, or whose record
# has a new slug, gets one redirect straight to the final path. A page that is not there still tells what it would be,
# so the admin can check where an editor's redirect may start.
class Seo::Pages::Resolve
  class Page < Data.define(:type, :record, :order_number, :page_number, :filters); end

  class Result < Data.define(:status, :page, :location)
    def self.found(page) = new(status: 200, page:, location: nil)

    def self.moved(location) = new(status: 301, page: nil, location:)

    def self.missing(page = nil) = new(status: 404, page:, location: nil)

    def self.gone(page = nil) = new(status: 410, page:, location: nil)
  end

  # The segments match in any case; a slug is looked up in lower case, an order number exactly as given.
  ROUTES = {
    %r{\A/\z} => :home,
    %r{\A/#{Seo::Pages::Path::SEGMENTS.fetch(:category)}/([^/]+)\z}i => :category,
    %r{\A/#{Seo::Pages::Path::SEGMENTS.fetch(:goods)}/([^/]+)\z}i => :goods,
    %r{\A/#{Seo::Pages::Path::SEGMENTS.fetch(:cart)}\z}i => :cart,
    %r{\A/#{Seo::Pages::Path::SEGMENTS.fetch(:order)}/([^/]+)\z}i => :order,
    # Last: a single segment that no route above takes is the slug of a static page.
    %r{\A/([^/]+)\z}i => :static
  }.freeze
  MODELS = { category: Catalog::Category, goods: Catalog::Goods, static: Seo::StaticPage }.freeze

  def self.call(path, config: Seo::Config.current) = new(path, config).call

  def initialize(path, config)
    raw_path, @query = path.to_s.split('?', 2)
    @config = config
    @paths = Seo::Pages::Path.new(config)
    @given = inside_section(raw_path.to_s)
  end

  def call
    type, key = (route if @given)
    return Result.missing unless type

    page_for(type, type == :order ? key.to_s : key.to_s.downcase)
  end

  private

  def page_for(type, key)
    params, page_dropped = known_params(type)
    page = build_page(type, key, params)
    return redirected(page, key, params) || Result.missing(page) if MODELS.key?(type) && page.record.nil?

    finish(page, key, params, normal?(page) && !page_dropped)
  end

  # The path inside the section as given, or nil when it lies outside the section's prefix. The home page of a prefixed
  # section is the empty rest, so `/apteka/` is told apart from `/apteka`.
  def inside_section(path)
    prefix = @paths.prefix
    return path.presence || '/' if prefix.empty?
    return unless path.downcase == prefix || path.downcase.start_with?("#{prefix}/")

    path[prefix.length..].to_s
  end

  def normal?(page) = @given == @paths.relative(normal_path(page))

  def route
    routed = @given.to_s.sub(%r{/+\z}, '').presence || '/'
    ROUTES.each do |pattern, type|
      match = pattern.match(routed) or next
      return [ type, match[1] ]
    end
    nil
  end

  def build_page(type, key, params)
    record = type == :home ? Seo::StaticPage.home : MODELS[type]&.find_by(slug: key)
    Page.new(type:, record:, order_number: (key if type == :order), page_number: params['page']&.to_i,
             filters: params.except('page'))
  end

  # An old slug leads to the current path of its record.
  def redirected(page, slug, params)
    record = redirect_record(page, slug) or return

    Result.moved(@paths.with_query(@paths.record(record).to_s, carried(page, record, params)))
  end

  # The record an old slug leads to, read through the cache; a redirect to a record that is gone leads nowhere, and an
  # editor's redirect leads only to a page that is there.
  def redirect_record(page, slug)
    target = Seo::Redirects::Cache.target(page.type.to_s, slug) or return
    record = MODELS.values.find { it.polymorphic_name == target.type }&.find_by(id: target.id)
    record unless target.manual && hidden_status(record)
  end

  # The page number and the filters go along only from a category to a category.
  def carried(page, record, params)
    # @type var none: Hash[String, String]
    none = {}
    page.type == :category && record.is_a?(Catalog::Category) ? params : none
  end

  def finish(page, slug, params, normal)
    status = hidden_status(page.record)
    # The slug of a record off the storefront is still its own, so only an editor's redirect can lead away from it.
    return redirected(page, slug, params) || Result.new(status:, page:, location: nil) if status
    return Result.found(page) if normal

    Result.moved(@paths.with_query(normal_path(page), params))
  end

  # The state of a page whose record is there but not on the storefront, or nil when it is.
  def hidden_status(record)
    case record
    when Catalog::Goods
      return 410 if record.withdrawn_with_group?

      404 unless record.shown?
    when Seo::StaticPage then 404 unless record.home? || record.published?
    end
  end

  def normal_path(page)
    case page.type
    when :home then @paths.home
    when :cart then @paths.cart
    when :order then @paths.order(page.order_number.to_s)
    else @paths.record(page.record).to_s
    end
  end

  # Parameters the page understands, filters first and the page number last, and whether a `page` was dropped for not
  # being a number above 1.
  def known_params(type)
    # @type var known: Hash[String, String]
    known = {}
    return [ known, false ] unless type == :category

    query.each { |name, value| known[name] = value if @config.filter_params.include?(name.downcase) }
    number = query.to_h['page'] or return [ known, false ]
    return [ known, true ] unless later_page?(number)

    [ known.merge('page' => number.to_i.to_s), false ]
  end

  def later_page?(number) = number.match?(/\A\d+\z/) && number.to_i > 1

  def query
    @parsed_query ||= URI.decode_www_form(@query.to_s).uniq(&:first)
  rescue ArgumentError
    @parsed_query = []
  end
end
