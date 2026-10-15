# frozen_string_literal: true

# A redirect an editor sets by hand: from the old address of a product, a category, a filter or a static page that has
# no page now (404 or 410) to a page of the section that is there. The target is kept as its record, so a later change
# of its slug leaves no chain; an address that itself redirects leads to where it ends. `save: false` only checks.
class Seo::Redirects::Manual
  SOURCE_TYPES = %i[goods category filter static].freeze
  TARGET_MODELS = [ Catalog::Goods, Catalog::Category, Seo::Filter, Seo::StaticPage ].freeze

  class Result < Data.define(:redirect, :errors)
    def ok? = errors.empty?
  end

  # `redirect` is a manual redirect whose target changes; its old address and period stay.
  def self.call(source:, target:, redirect: nil, save: true, config: Seo::Config.current)
    new(config).call(source:, target:, redirect:, save:)
  end

  # Why a redirect could not lead to the target, or nil when it could: for a page that still has its address, so its
  # target is checked before the page goes.
  def self.target_error(target, config: Seo::Config.current)
    # @type var errors: Hash[Symbol, Symbol]
    errors = {}
    new(config).send(:target_record, target, errors)
    errors[:target]
  end

  def initialize(config)
    @config = config
  end

  def call(source:, target:, redirect:, save:)
    # @type var errors: Hash[Symbol, Symbol]
    errors = {}
    redirect ||= from(source, errors)
    record = target_record(target, errors)
    return Result.new(redirect: nil, errors:) if errors.any? || redirect.nil? || record.nil?

    redirect.redirectable = record
    return Result.new(redirect:, errors:) unless save

    store(redirect)
  end

  private

  # A new redirect from the old address, or nil with the reason in `errors`.
  def from(source, errors)
    address = Seo::Pages::Address.call(source, config: @config)
    return refuse(errors, :source, address.error || :invalid) unless address.ok?

    path = address.path.to_s
    result = Seo::Pages::Resolve.call(path, config: @config)
    reason = source_error(result)
    return refuse(errors, :source, reason) if reason

    Seo::Redirect.new(manual: true, page_type: result.page&.type.to_s, slug: path.split('/').last.to_s)
  end

  def source_error(result)
    return :not_a_page unless SOURCE_TYPES.include?(result.page&.type) || result.status == 301
    return :redirected if result.status == 301

    :page_there if result.status == 200
  end

  # The record of the page the address shows.
  def target_record(target, errors)
    address = Seo::Pages::Address.call(target, config: @config)
    return refuse(errors, :target, address.error || :invalid) unless address.ok?

    result = ending(address.path.to_s)
    return refuse(errors, :target, result.page ? :unavailable : :not_a_page) unless result.status == 200

    record = result.page&.record
    TARGET_MODELS.any? { record.is_a?(it) } ? record : refuse(errors, :target, :not_a_page)
  end

  # Where the path ends: the endpoint gives one redirect straight to the final path, so one step is enough.
  def ending(path)
    result = Seo::Pages::Resolve.call(path, config: @config)
    result.status == 301 ? Seo::Pages::Resolve.call(result.location.to_s, config: @config) : result
  end

  def refuse(errors, field, reason)
    errors[field] = reason
    nil
  end

  # Two editors may set a redirect from the same address at once; the unique index lets one of them through.
  def store(redirect)
    return Result.new(redirect:, errors: {}) if redirect.save

    Result.new(redirect: nil, errors: { source: :redirected })
  rescue ActiveRecord::RecordNotUnique
    Result.new(redirect: nil, errors: { source: :redirected })
  end
end
