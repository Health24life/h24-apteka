# frozen_string_literal: true

# Asks Pharmapoint what drugstores have of goods of the catalog and at what price: one call, never repeated, while a
# user waits. SKUs and drugstores are turned into the partner's ids on the way out and back into the catalog's on the
# way in. A failure of the partner or of the links becomes an answer of its own, so the caller decides how to show it;
# any other error is a bug and is raised.
class Pharmapoint::Offers
  # A SKU or a drugstore the provider has no id for: nothing can be asked, and nothing is wrong with the partner.
  class NotLinked < StandardError; end

  attr_reader :provider

  def initialize(provider:, user_id: nil, config: Pharmapoint.config, rate_limiter: Pharmapoint::RateLimiter.new(config:))
    @provider = provider
    @client = Pharmapoint::Client.new(provider:, config:, purpose: :offers, user_id:, rate_limiter:)
  end

  # The drugstores around the place that have one pack of the SKU.
  def nearby(goods, location)
    refs = goods_refs([ goods ])
    lines = [ Pharmapoint::OrderLine.new(external_id: refs.fetch(goods.id), quantity: 1) ]
    offers = @client.offers_nearby(goods: lines, location: point(location))
    drugstores = drugstore_ids(offers.map(&:drugstore_external_id))
    offers.map { offer(it, drugstores[it.drugstore_external_id], refs) }
  rescue Pharmapoint::Error, NotLinked => e
    failure(e)
  end

  # What the drugstore has of the items, all of them in one call. A booking asks with no share of the limit.
  def in_drugstore(drugstore, items, share: :cart)
    refs = goods_refs(items.map { sku(it) })
    external_id = drugstore_ref(drugstore)
    found = @client.offers_in_drugstore(goods: order_lines(items, refs), drugstore_external_id: external_id, share:)
      .find { it.drugstore_external_id == external_id }
    found ? offer(found, drugstore.id, refs) : Orders::Offers::DrugstoreOffer.unknown(drugstore.id)
  rescue Pharmapoint::Error, NotLinked => e
    failure(e)
  end

  private

  def point(location)
    Pharmapoint::SearchPoint.new(latitude: location.latitude, longitude: location.longitude, radius: location.radius)
  end

  # One line per SKU, however many items of the cart hold it, so that the partner checks the stock against all of them.
  # The partner counts whole packs and the cart lets in only them: a part of a pack here is a bug, not a quantity.
  def order_lines(items, refs)
    items.group_by { sku(it).id }.map do |goods_id, same|
      quantity = same.sum(BigDecimal(0), &:quantity)
      if quantity.frac.nonzero?
        raise ArgumentError, "goods #{goods_id} are asked in a part of a pack: #{quantity.to_s('F')}"
      end

      Pharmapoint::OrderLine.new(external_id: refs.fetch(goods_id), quantity: quantity.to_i)
    end
  end

  def drugstore_ref(drugstore)
    drugstore.provider_ref(@provider) || raise(NotLinked, "drugstore #{drugstore.id} is not linked")
  end

  def sku(item) = item.goods || raise(ArgumentError, 'an item has no SKU')

  # The partner's id of every SKU, by the SKU's id.
  def goods_refs(goods)
    Provider::Link.where(provider: @provider, linkable: goods).pluck(:linkable_id, :external_id).to_h.tap do |refs|
      missing = goods.map(&:id) - refs.keys
      raise NotLinked, "goods #{missing.join(', ')} are not linked" if missing.any?
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

  # A line of an id the partner was not asked about is dropped, so its SKU reads as not covered. An answer of which no
  # line is one asked about tells nothing of the goods: it is no data, not a drugstore without them.
  def lines(items, goods_ids)
    return unless items

    found = items.filter_map do |item|
      goods_id = goods_ids[item.goods_external_id]
      next unless goods_id

      Orders::Offers::Line.new(
        goods_id:,
        fulfilled: item.fulfilled,
        price: item.price,
        available_quantity: item.quantity&.floor.to_i
      )
    end
    found unless found.empty? && items.any?
  end

  def failure(error)
    case error
    when Pharmapoint::RateLimited then Orders::Offers::Failure.new(
      reason: :rate_limited,
      retry_after: error.retry_after
    )
    when Pharmapoint::TransientError then Orders::Offers::Failure.new(reason: :unavailable, retry_after: nil)
    when NotLinked
      Rails.logger.warn("[pharmacy_offers] #{@provider.code}: #{error.message}")
      Orders::Offers::Failure.new(reason: :unavailable, retry_after: nil)
    else
      Rails.error.report(error, handled: true, context: { source: 'pharmacy_offers', provider: @provider.code })
      Orders::Offers::Failure.new(reason: :unavailable, retry_after: nil)
    end
  end
end
