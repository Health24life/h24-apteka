# frozen_string_literal: true

# Settings of the section's SEO data. They come from the environment, so a host or a period changes without code.
class Seo::Config < Data.define(:front_base_url, :filter_params, :forbidden_words, :redirect_ttl, :sitemap_storage,
                                :sitemap_dir, :sitemap_s3)
  class MissingSetting < StandardError; end

  # Where the sitemap goes in the S3 storage: an S3-compatible service such as MinIO.
  class S3 < Data.define(:bucket, :endpoint, :region, :access_key_id, :secret_access_key); end

  SITEMAP_STORAGES = %w[file s3].freeze

  # Every form of "buy" and "price" a merchant would write; a word that only starts the same, like «цінний», is fine.
  FORBIDDEN_WORDS = %w[
    купити купіть купуйте купи купую куплю купувати купівля купівлі купівлю купівлею
    ціна ціни ціні ціну ціною цін цінам цінами цінах
  ].freeze

  def self.current = @current ||= from_env

  def self.reset! = @current = nil

  def self.from_env(env = ENV)
    new(
      front_base_url: env.fetch('APTEKA_FRONT_BASE_URL', nil).presence&.delete_suffix('/'),
      filter_params: list(env.fetch('SEO_FILTER_PARAMS', nil)),
      forbidden_words: list(env.fetch('SEO_FORBIDDEN_WORDS', nil)).presence || FORBIDDEN_WORDS,
      redirect_ttl: Integer(env.fetch('SEO_REDIRECT_TTL_MONTHS', 3)).months,
      **sitemap(env)
    )
  end

  def self.sitemap(env)
    { sitemap_storage: env.fetch('SEO_SITEMAP_STORAGE', nil).presence || 'file',
      sitemap_dir: env.fetch('SEO_SITEMAP_DIR', nil).presence, sitemap_s3: s3(env) }
  end

  def self.s3(env)
    S3.new(bucket: env.fetch('SEO_SITEMAP_S3_BUCKET', nil).presence,
           endpoint: env.fetch('SEO_SITEMAP_S3_ENDPOINT', nil).presence,
           region: env.fetch('SEO_SITEMAP_S3_REGION', nil).presence || 'us-east-1',
           access_key_id: env.fetch('SEO_SITEMAP_S3_ACCESS_KEY_ID', nil).presence,
           secret_access_key: env.fetch('SEO_SITEMAP_S3_SECRET_ACCESS_KEY', nil).presence)
  end

  def self.list(value) = value.to_s.split(',').map { it.strip.downcase }.compact_blank

  private_class_method :sitemap, :s3

  # rubocop:disable-next Metrics/ParameterLists -- a settings object takes every setting as a keyword.
  def initialize(front_base_url: nil, filter_params: [], forbidden_words: FORBIDDEN_WORDS, redirect_ttl: 3.months,
                 sitemap_storage: 'file', sitemap_dir: nil, sitemap_s3: nil)
    super
  end

  # The scheme, host and the section's path prefix of the front, without a trailing slash: `https://apteka.h24.ua`.
  def front_base_url!
    front_base_url.presence || raise(MissingSetting, 'APTEKA_FRONT_BASE_URL is not set')
  end

  def sitemap_dir!
    sitemap_dir.presence || raise(MissingSetting, 'SEO_SITEMAP_DIR is not set')
  end

  def sitemap_s3!
    s3 = sitemap_s3 or raise MissingSetting, 'SEO_SITEMAP_S3_BUCKET is not set'
    raise MissingSetting, 'SEO_SITEMAP_S3_BUCKET is not set' if s3.bucket.blank?
    raise MissingSetting, 'SEO_SITEMAP_S3_ENDPOINT is not set' if s3.endpoint.blank?

    s3
  end

  def sitemap_storage!
    return sitemap_storage if SITEMAP_STORAGES.include?(sitemap_storage)

    raise MissingSetting, "SEO_SITEMAP_STORAGE must be one of #{SITEMAP_STORAGES.join(', ')}, not #{sitemap_storage}"
  end

  # The path prefix of the section on the front host, empty while the section lives at the root of its own subdomain.
  def front_path_prefix = URI.parse(front_base_url!).path.to_s.delete_suffix('/')
end
