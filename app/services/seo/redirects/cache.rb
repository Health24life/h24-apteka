# frozen_string_literal: true

# The redirects as the SEO endpoint reads them: an old slug of a kind of page leads to the type and id of the record and
# whether an editor set it by hand, kept in Redis for as long as the redirect lives. The table stays the source of
# truth: a slug Redis does not hold is looked up there and cached, and while Redis is unreachable the table answers
# alone, so a lost key never turns a redirect into a missing page. `rebuild` refills the cache in one go after Redis
# lost its keys.
class Seo::Redirects::Cache
  PREFIX = "h24_apteka:#{Rails.env}:seo:redirect".freeze
  # `type:id:manual`; a value written before the flag existed has no third part and is an automatic redirect.
  VALUE = /\A(?<type>.+?):(?<id>\d+)(?::(?<manual>[01]))?\z/

  class Target < Data.define(:type, :id, :manual)
    def self.of(redirect) = new(type: redirect.redirectable_type, id: redirect.redirectable_id, manual: redirect.manual)
  end

  def self.redis = @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))

  def self.write(redirect, config: Seo::Config.current)
    ttl = (redirect.created_at + config.redirect_ttl - Time.current).to_i
    return delete(redirect) unless ttl.positive?

    reporting { redis.set(key(redirect.page_type, redirect.slug), value(redirect), ex: ttl) }
  end

  def self.value(redirect) = "#{redirect.redirectable_type}:#{redirect.redirectable_id}:#{redirect.manual ? 1 : 0}"

  def self.delete(redirect) = reporting { redis.del(key(redirect.page_type, redirect.slug)) }

  # Where an old slug of a kind of page leads.
  def self.target(page_type, slug)
    cached = reporting { redis.get(key(page_type, slug)) }&.match(VALUE)
    return Target.new(type: cached[:type], id: cached[:id].to_i, manual: cached[:manual] == '1') if cached

    redirect = Seo::Redirect.active.find_by(page_type:, slug:) or return
    write(redirect)
    Target.of(redirect)
  end

  # Drops every cached redirect and writes the active ones again. Returns how many it wrote.
  def self.rebuild
    clear
    Seo::Redirect.active.find_each.count { write(it) }
  end

  def self.clear = redis.scan_each(match: "#{PREFIX}:*").each_slice(500) { redis.del(*it) }

  def self.key(page_type, slug) = "#{PREFIX}:#{page_type}:#{slug}"

  # A Redis failure must not fail the save of a redirect or a request for a page: the table still knows the answer.
  def self.reporting
    yield
  rescue Redis::BaseError => e
    Rails.error.report(e, handled: true)
    nil
  end

  private_class_method :value, :reporting
end
