# frozen_string_literal: true

# Settings of the section's SEO data. They come from the environment, so a host or a period changes without code.
class Seo::Config < Data.define(:front_base_url, :filter_params, :forbidden_words, :redirect_ttl, :sitemap_dir)
  class MissingSetting < StandardError; end

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
      sitemap_dir: env.fetch('SEO_SITEMAP_DIR', nil).presence
    )
  end

  def self.list(value) = value.to_s.split(',').map { it.strip.downcase }.compact_blank

  def initialize(front_base_url: nil, filter_params: [], forbidden_words: FORBIDDEN_WORDS, redirect_ttl: 3.months,
                 sitemap_dir: nil)
    super
  end

  # The scheme, host and the section's path prefix of the front, without a trailing slash: `https://apteka.h24.ua`.
  def front_base_url!
    front_base_url.presence || raise(MissingSetting, 'APTEKA_FRONT_BASE_URL is not set')
  end

  def sitemap_dir!
    sitemap_dir.presence || raise(MissingSetting, 'SEO_SITEMAP_DIR is not set')
  end

  # The path prefix of the section on the front host, empty while the section lives at the root of its own subdomain.
  def front_path_prefix = URI.parse(front_base_url!).path.to_s.delete_suffix('/')
end
