# frozen_string_literal: true

# Reads the catalog and the drugstore directory from the partner API, and the live prices and stock of drugstores. Every
# call is paced, logged and checked by the transport and answers with plain values: the catalog readers drop the live
# fields, the offer readers keep only them.
class Pharmapoint::Client
  GOODS_GROUPS_PATH = 'goods-group/search'
  GOODS_GROUP_PATH = 'goods-group/get-by-id'
  DICTIONARIES_PATH = 'dictionaries'
  CATEGORY_TREE_PATH = 'category/tree'
  DRUGSTORES_PATH = 'drugstore'
  DRUGSTORE_PATH = 'drugstore/%<id>s'
  # The two differ by one letter: the plural one looks around a point, the singular one in the drugstores named.
  OFFERS_NEARBY_PATH = 'order/get-drugstores-for-order-goods'
  OFFERS_IN_DRUGSTORE_PATH = 'order/get-drugstore-for-order-goods'
  STORE_PICK_UP_ORDER_PATH = 'order/store-pick-up-order'
  ORDER_PATH = 'order/%<number>s'
  ORDER_HISTORY_PATH = 'order/history'
  ORDER_HISTORY_PER_PAGE = 50
  CANCEL_ORDER_PATH = 'order/cancel'

  # rubocop:disable-next Metrics/ParameterLists -- who asks, why and which attempt it is are the log's context.
  def initialize(
    provider:,
    config: Pharmapoint.config,
    purpose: :refresh,
    user_id: nil,
    sync_run: nil,
    attempt: 1,
    rate_limiter: Pharmapoint::RateLimiter.new(config:)
  )
    @config = config
    masker = Pharmapoint::Logging::Masker.new(config:)
    logger = Pharmapoint::Logging::RequestLogger.new(
      provider:,
      category: purpose,
      user_id:,
      sync_run:,
      attempt:,
      masker:
    )
    @transport = Pharmapoint::Transport.new(config:, rate_limiter:, masker:, logger:)
  end

  def dictionaries = fetch(DICTIONARIES_PATH) { Pharmapoint::Readers::Dictionaries.call(it) }

  def category_tree = fetch(CATEGORY_TREE_PATH) { Pharmapoint::Readers::Categories.call(it) }

  def goods_groups(page:, per_page: @config.goods_groups_per_page)
    fetch(GOODS_GROUPS_PATH, { page:, per_page: }) { Pharmapoint::Readers::GoodsGroups.page(it, page:, per_page:) }
  end

  # The live search of a user: the groups found by the text around a point, and the records of the groups as the
  # partner gave them, for a save that need not ask again. It spends the search's share of the limit and has timeouts
  # of its own; the read timeout may be cut to what is left of the user's request. No client's phone goes with it.
  def search_goods_groups(query:, page:, location:, per_page: @config.search.per_page, read_timeout: nil)
    search = @config.search
    timeouts = { open_timeout: search.open_timeout, timeout: read_timeout || search.read_timeout }
    params = { query:, page:, per_page:, **location.to_h }
    fetch(GOODS_GROUPS_PATH, params, share: :search, timeouts:) { Pharmapoint::Readers::GoodsGroups.found(it, page:, per_page:) }
  end

  def goods_group(external_id)
    fetch(GOODS_GROUP_PATH, { id: external_id }) { Pharmapoint::Readers::GoodsGroups.one(it) }
  end

  def drugstores(point)
    params = { latitude: point.latitude, longitude: point.longitude, radius: point.radius }
    fetch(DRUGSTORES_PATH, params) { Pharmapoint::Readers::Drugstores.list(it) }
  end

  def drugstore(external_id)
    fetch(format(DRUGSTORE_PATH, id: external_id)) { Pharmapoint::Readers::Drugstores.one(it) }
  end

  # The drugstores around a point that have the goods, each with its price and the quantity it has. Only drugstores with
  # stock are asked for. No client's phone goes with it.
  def offers_nearby(goods:, location:)
    body = { goods: goods.map { offer_line(it) }, **location.to_h }
    deliver(OFFERS_NEARBY_PATH, body, { with_empty_stock: 0 }) { Pharmapoint::Readers::Offers.call(it) }
  end

  # What one drugstore has of the goods. Drugstores without stock are asked for too, so that a missing item comes back
  # as such rather than as no drugstore at all.
  # The cart spends its share of the limit; a booking confirming its prices spends none.
  def offers_in_drugstore(goods:, drugstore_external_id:, share: :cart)
    body = { goods: goods.map { offer_line(it) }, drugstore_id: drugstore_external_id }
    deliver(OFFERS_IN_DRUGSTORE_PATH, body, { with_empty_stock: 1 }, share:) { Pharmapoint::Readers::Offers.call(it) }
  end

  # Makes a pick-up order at the partner and gives it back as the partner saved it.
  def store_pick_up_order(body)
    ordering(STORE_PICK_UP_ORDER_PATH, {}, body:) { Pharmapoint::Readers::PartnerOrders.one(it) }
  end

  def order(number)
    path = format(ORDER_PATH, number: ERB::Util.url_encode(number))
    ordering(path, {}) { Pharmapoint::Readers::PartnerOrders.one(it) }
  end

  # The latest orders of a client, known to the partner by the phone; the phone goes in a header the log masks.
  def order_history(phone:)
    params = { page: 1, per_page: ORDER_HISTORY_PER_PAGE, sort_by: 'created_at', sort_direction: 'desc' }
    headers = { 'Customer-Phone' => phone }
    ordering(ORDER_HISTORY_PATH, params, headers:) { Pharmapoint::Readers::PartnerOrders.many(it) }
  end

  # Asks the partner to cancel an order; the partner checks the client's phone. What it answers is not documented, so
  # any successful answer is taken as done.
  def cancel_order(number:, phone:, reason:)
    body = { order_number: number, cancel_reason: reason }
    ordering(CANCEL_ORDER_PATH, {}, body:, headers: { 'Customer-Phone' => phone }) { true }
  end

  private

  # Orders spend no share of the limit and have the booking's timeouts.
  def ordering(path, params, body: nil, headers: nil, &)
    booking = @config.booking
    timeouts = { open_timeout: booking.open_timeout, timeout: booking.read_timeout }
    fetch(path, params, body:, headers:, timeouts:, &)
  end

  def offer_line(line) = { goods_id: line.external_id, quantity: line.quantity }

  # The live offers have the cart's short timeouts and spend its share of the limit unless told otherwise.
  def deliver(path, body, params, share: :cart, &)
    cart = @config.cart
    timeouts = { open_timeout: cart.open_timeout, timeout: cart.read_timeout }
    fetch(path, params, body:, share:, timeouts:, &)
  end

  def fetch(path, params = {}, **, &) = @transport.call(path, params, **, &)
end
