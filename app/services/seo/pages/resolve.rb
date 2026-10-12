# frozen_string_literal: true

# Tells what a path of the front shows: a page, a permanent redirect to another path, or no page at all.
#
# Only the parameters the page understands are kept: `page` and the filters on a category. Anything else, UTM tags
# included, neither changes the answer nor reaches a redirect. A path that is not in its normal form, or whose record
# has a new slug, gets one redirect straight to the final path.
class Seo::Pages::Resolve
  class Page < Data.define(:type, :record, :order_number, :page_number, :filters); end

  class Result < Data.define(:status, :page, :location)
    def self.found(page) = new(status: 200, page:, location: nil)

    def self.moved(location) = new(status: 301, page: nil, location:)

    def self.missing = new(status: 404, page: nil, location: nil)

    def self.gone = new(status: 410, page: nil, location: nil)
  end

  ROUTES = {
    %r{\A/\z} => :home,
    %r{\A/#{Seo::Pages::Path::SEGMENTS.fetch(:category)}/([^/]+)\z} => :category,
    %r{\A/#{Seo::Pages::Path::SEGMENTS.fetch(:goods)}/([^/]+)\z} => :goods,
    %r{\A/#{Seo::Pages::Path::SEGMENTS.fetch(:cart)}\z} => :cart,
    %r{\A/#{Seo::Pages::Path::SEGMENTS.fetch(:order)}/([^/]+)\z} => :order
  }.freeze
  MODELS = { category: Catalog::Category, goods: Catalog::Goods }.freeze

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

    params, page_dropped = known_params(type)
    page = build_page(type, key.to_s, params)
    return record_missing(type, key.to_s, params) if MODELS.key?(type) && page.record.nil?

    finish(page, params, normal? && !page_dropped)
  end

  private

  # The path inside the section as given, or nil when it lies outside the section's prefix.
  def inside_section(path)
    prefix = @paths.prefix
    return path.presence || '/' if prefix.empty?
    return unless path.downcase == prefix || path.downcase.start_with?("#{prefix}/")

    path[prefix.length..].presence || '/'
  end

  def normal_relative = @normal_relative ||= @given.to_s == '/' ? '/' : @given.to_s.downcase.sub(%r{/+\z}, '')

  def normal? = @given == normal_relative

  def route
    ROUTES.each do |pattern, type|
      match = pattern.match(normal_relative.presence || '/') or next
      return [ type, match[1] ]
    end
    nil
  end

  def build_page(type, key, params)
    record = MODELS[type]&.find_by(slug: key)
    Page.new(type:, record:, order_number: (key if type == :order), page_number: params['page']&.to_i,
             filters: params.except('page'))
  end

  def record_missing(type, slug, params)
    redirect = Seo::Redirect.active.find_by(redirectable_type: MODELS.fetch(type).polymorphic_name, slug:)
    return Result.missing unless redirect

    Result.moved(@paths.with_query(@paths.record(redirect.redirectable).to_s, params))
  end

  def finish(page, params, normal)
    record = page.record
    if record.is_a?(Catalog::Goods)
      return Result.gone if record.withdrawn_with_group?
      return Result.missing unless record.shown?
    end
    return Result.found(page) if normal

    Result.moved(@paths.with_query(normal_path(page), params))
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
