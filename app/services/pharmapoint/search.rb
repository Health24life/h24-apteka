# frozen_string_literal: true

# Searches Pharmapoint for the goods of a query: one call, never repeated, within the time the user's request has left.
# The found groups are turned into neutral hits, and their records are kept for the catalog to save. A failure becomes
# an answer of its own, so the other providers and queries go on.
class Pharmapoint::Search
  attr_reader :provider

  def initialize(provider:, user_id: nil, config: Pharmapoint.config, rate_limiter: Pharmapoint::RateLimiter.new(config:))
    @provider = provider
    @config = config
    @rate_limiter = rate_limiter
    @client = Pharmapoint::Client.new(provider:, config:, purpose: :search, user_id:, rate_limiter:)
  end

  def call(query, time_left:)
    return failure(:unavailable) if time_left < @config.search.open_timeout

    groups, records = search(query, time_left)
    page(groups, records)
  rescue Pharmapoint::RateLimited => e
    failure(:rate_limited, e.retry_after)
  rescue Pharmapoint::TransientError
    failure(:unavailable)
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { source: 'catalog_search', provider: @provider.code })
    failure(:unavailable)
  end

  private

  def search(query, time_left)
    location = query.location
    point = Pharmapoint::SearchPoint.new(
      latitude: location.latitude,
      longitude: location.longitude,
      radius: location.radius
    )
    measured do
      @client.search_goods_groups(
        query: query.text,
        page: query.page,
        location: point,
        read_timeout: [ @config.search.read_timeout, time_left ].min
      )
    end
  end

  # The time of the call and what is left of the share after it, whether it answered or not.
  def measured
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
  ensure
    code = @provider.code
    Catalog::Search::Metrics.duration(code, (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to_f) if started
    Catalog::Search::Metrics.share_left(code) { @rate_limiter.remaining(share: :search) }
  end

  def page(groups, records)
    Catalog::Search::ProviderPage.new(
      provider: @provider.code,
      hits: groups.items.flat_map { |group| group.goods.map { hit(group, it) } },
      per_page: groups.per_page,
      total_groups: groups.total,
      has_more: !groups.last?,
      records:
    )
  end

  def hit(group, goods)
    Catalog::Search::Hit.new(**group_fields(group), **goods_fields(goods), ready: false, id: nil, slug: nil)
  end

  def group_fields(group)
    producer = group.producer
    {
      provider: @provider.code,
      group_external_id: group.external_id,
      group_name: group.name,
      trade_name: group.goods_name&.name,
      producer_name: producer&.name,
      producer_country_code: producer&.country_code
    }
  end

  def goods_fields(goods)
    card = goods.card
    {
      external_id: goods.external_id,
      name: goods.name,
      release_form: card.release_form,
      dosage: card.dosage,
      pack: pack(goods.pack),
      is_recipe: card.is_recipe,
      is_strict_recipe: card.is_strict_recipe
    }
  end

  def pack(pack)
    {
      unit_name: pack.unit_name,
      quantity_in_pack: pack.quantity_in_pack,
      quantity_unit_in_pack: pack.quantity_unit_in_pack,
      quantity_in_unit: pack.quantity_in_unit
    }
  end

  def failure(reason, retry_after = nil)
    Catalog::Search::Failure.new(provider: @provider.code, reason:, retry_after:)
  end
end
