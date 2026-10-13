# frozen_string_literal: true

# The redirects as the SEO endpoint reads them: an old slug of a kind of record leads to the id of the record, kept in
# Redis for as long as the redirect lives. The table stays the source of truth; `rebuild` refills the cache from it
# after Redis lost its keys.
class Seo::Redirects::Cache
  PREFIX = "h24_apteka:#{Rails.env}:seo:redirect".freeze

  def self.redis = @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))

  def self.write(redirect, config: Seo::Config.current)
    ttl = (redirect.created_at + config.redirect_ttl - Time.current).to_i
    return delete(redirect) unless ttl.positive?

    redis.set(key(redirect.redirectable_type, redirect.slug), redirect.redirectable_id, ex: ttl)
  end

  def self.delete(redirect) = redis.del(key(redirect.redirectable_type, redirect.slug))

  def self.target_id(type, slug) = redis.get(key(type, slug))&.to_i

  # Drops every cached redirect and writes the active ones again. Returns how many it wrote.
  def self.rebuild
    clear
    Seo::Redirect.active.find_each.count { write(it) }
  end

  def self.clear = redis.scan_each(match: "#{PREFIX}:*").each_slice(500) { redis.del(*it) }

  def self.key(type, slug) = "#{PREFIX}:#{type}:#{slug}"
end
