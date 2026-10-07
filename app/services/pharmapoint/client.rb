# frozen_string_literal: true

# Reads the catalog and the drugstore directory from the partner API. Every call is paced against the partner's
# request limit, logged, and answers with plain values: live fields are dropped by the readers.
class Pharmapoint::Client
  GOODS_GROUPS_PATH = 'goods-group/search'
  GOODS_GROUP_PATH = 'goods-group/get-by-id'
  DICTIONARIES_PATH = 'dictionaries'
  CATEGORY_TREE_PATH = 'category/tree'
  DRUGSTORES_PATH = 'drugstore'
  DRUGSTORE_PATH = 'drugstore/%<id>s'
  ERROR_BODY_LIMIT = 500

  # rubocop:disable-next Metrics/ParameterLists -- who asks, why and which attempt it is are the log's context.
  def initialize(provider:, config: Pharmapoint::Config.current, purpose: :refresh, user_id: nil, sync_run: nil,
                 attempt: 1, rate_limiter: Pharmapoint::RateLimiter.new(config:))
    @config = config
    @rate_limiter = rate_limiter
    @masker = Pharmapoint::Logging::Masker.new(config:)
    @logger = Pharmapoint::Logging::RequestLogger.new(provider:, category: purpose, user_id:, sync_run:, attempt:,
                                                      masker: @masker)
  end

  def dictionaries = fetch(DICTIONARIES_PATH) { Pharmapoint::Readers::Dictionaries.call(it) }

  def category_tree = fetch(CATEGORY_TREE_PATH) { Pharmapoint::Readers::Categories.call(it) }

  def goods_groups(page:, per_page: @config.goods_groups_per_page)
    fetch(GOODS_GROUPS_PATH, page:, per_page:) { Pharmapoint::Readers::GoodsGroups.page(it, page:, per_page:) }
  end

  def goods_group(external_id)
    fetch(GOODS_GROUP_PATH, id: external_id) { Pharmapoint::Readers::GoodsGroups.one(it) }
  end

  def drugstores(point)
    params = { latitude: point.latitude, longitude: point.longitude, radius: point.radius }
    fetch(DRUGSTORES_PATH, params) { Pharmapoint::Readers::Drugstores.list(it) }
  end

  def drugstore(external_id)
    fetch(format(DRUGSTORE_PATH, id: external_id)) { Pharmapoint::Readers::Drugstores.one(it) }
  end

  private

  def fetch(path, params = {})
    @rate_limiter.guard!
    response = request(path, params)
    @rate_limiter.record(response.headers)
    check_status!(response)
    yield parse(response.body)
  rescue Pharmapoint::InvalidResponse
    @logger.mark_invalid_response!
    raise
  end

  def request(path, params)
    connection.get(path, params)
  rescue Faraday::Error => e
    raise Pharmapoint::TransientError, @masker.text(e.message)
  end

  # Only a successful answer is read as JSON: an error page of a gateway has no reason to be.
  def parse(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError => e
    raise Pharmapoint::InvalidResponse, @masker.text(e.message)
  end

  def check_status!(response)
    status = response.status
    return if status.between?(200, 299)

    message = "Pharmapoint answered #{status}: #{@masker.text(response.body.to_s).first(ERROR_BODY_LIMIT)}"
    raise rate_limited(response) if status == 429
    raise Pharmapoint::TransientError, message if status >= 500

    raise Pharmapoint::PermanentError.new(message, status:)
  end

  def rate_limited(response)
    wait = Integer(response.headers['retry-after'], exception: false) || @config.rate_limit_window
    @rate_limiter.block!(wait)
    Pharmapoint::RateLimited.new(wait)
  end

  def connection
    api_key, domain_name = @config.credentials!
    Faraday.new(url: @config.base_url, headers: { 'API-Key' => api_key, 'Domain-Name' => domain_name,
                                                  'Accept' => 'application/json' },
                request: { open_timeout: @config.open_timeout, timeout: @config.read_timeout }) do |faraday|
      faraday.use Pharmapoint::Logging::Middleware, logger: @logger
      faraday.adapter :typhoeus
    end
  end
end
