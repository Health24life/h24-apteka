# frozen_string_literal: true

# Asks Pharmapoint what drugstores have of goods of the catalog and at what price: one call, never repeated, while a
# user waits. SKUs and drugstores are turned into the partner's ids on the way out and back into the catalog's on the
# way in. A failure becomes an answer of its own, so the caller decides how to show it.
class Pharmapoint::Offers
  attr_reader :provider

  def initialize(provider:, user_id: nil, config: Pharmapoint.config, rate_limiter: Pharmapoint::RateLimiter.new(config:))
    @provider = provider
    @client = Pharmapoint::Client.new(provider:, config:, purpose: :booking, user_id:, rate_limiter:)
  end

  # The drugstores around the place that have one pack of the SKU.
  def nearby(goods, location)
    refs = goods_refs([ goods ])
    lines = [ Pharmapoint::OrderLine.new(external_id: refs.fetch(goods.id), quantity: 1) ]
    offers = @client.offers_nearby(goods: lines, location: point(location))
    drugstores = drugstore_ids(offers.map(&:drugstore_external_id))
    offers.map { offer(it, drugstores[it.drugstore_external_id], refs) }
  rescue StandardError => e
    failure(e)
  end

  # What the drugstore has of the items, all of them in one call.
  def in_drugstore(drugstore, items)
    refs = goods_refs(items.map { sku(it) })
    external_id = drugstore_ref(drugstore)
    found = @client.offers_in_drugstore(goods: order_lines(items, refs), drugstore_external_id: external_id)
      .find { it.drugstore_external_id == external_id }
    found ? offer(found, drugstore.id, refs) : Orders::Offers::DrugstoreOffer.unknown(drugstore.id)
  rescue StandardError => e
    failure(e)
  end

  private

  def point(location)
    Pharmapoint::SearchPoint.new(latitude: location.latitude, longitude: location.longitude, radius: location.radius)
  end

  def order_lines(items, refs)
    items.map { Pharmapoint::OrderLine.new(external_id: refs.fetch(sku(it).id), quantity: it.quantity.to_i) }
  end

  def drugstore_ref(drugstore)
    drugstore.provider_ref(@provider) || raise(ArgumentError, "drugstore #{drugstore.id} is not linked")
  end

  def sku(item) = item.goods || raise(ArgumentError, 'an item has no SKU')

  # The partner's id of every SKU, by the SKU's id.
  def goods_refs(goods)
    Provider::Link.where(provider: @provider, linkable: goods).pluck(:linkable_id, :external_id).to_h.tap do |refs|
      missing = goods.map(&:id) - refs.keys
      raise ArgumentError, "goods #{missing.join(', ')} are not linked" if missing.any?
    end
  end

  # The catalog's id of every drugstore the directory has, by the partner's id.
  def drugstore_ids(external_ids)
    Provider::Link
      .where(provider: @provider, linkable_type: Catalog::Drugstore.polymorphic_name, external_id: external_ids)
      .pluck(:external_id, :linkable_id)
      .to_h
  end

  def offer(offer, drugstore_id, refs)
    hours = offer.today_hours
    Orders::Offers::DrugstoreOffer.new(
      drugstore_id:,
      distance: offer.distance,
      open_now: hours.open,
      opens_at: hours.from,
      closes_at: hours.to,
      round_the_clock: hours.round_the_clock,
      lines: lines(offer.items, refs.invert)
    )
  end

  # A line of an id the partner was not asked about is dropped, so its SKU reads as not covered.
  def lines(items, goods_ids)
    items&.filter_map do |item|
      goods_id = goods_ids[item.goods_external_id]
      next unless goods_id

      Orders::Offers::Line.new(
        goods_id:,
        fulfilled: item.fulfilled,
        price: item.price,
        available_quantity: item.quantity&.floor.to_i
      )
    end
  end

  def failure(error)
    case error
    when Pharmapoint::RateLimited then Orders::Offers::Failure.new(
      reason: :rate_limited,
      retry_after: error.retry_after
    )
    when Pharmapoint::TransientError then Orders::Offers::Failure.new(reason: :unavailable, retry_after: nil)
    else
      Rails.error.report(error, handled: true, context: { source: 'pharmacy_offers', provider: @provider.code })
      Orders::Offers::Failure.new(reason: :unavailable, retry_after: nil)
    end
  end
end
