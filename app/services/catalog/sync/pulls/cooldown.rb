# frozen_string_literal: true

# A record whose fetch failed for good is not queued again for a while: the same failure would only repeat. The pauses
# live in Redis, so every process sees them.
class Catalog::Sync::Pulls::Cooldown
  PREFIX = 'catalog_sync_pull_cooldown'

  def self.pause!(provider_id, type, external_id, config: Catalog::Sync.config)
    Sidekiq.redis do |redis|
      redis.call('SET', key(provider_id, type, external_id), '1', 'EX', config.pull.cooldown.to_i)
    end
  end

  # The ids among the given ones whose records are paused.
  def self.paused(provider_id, type, ids)
    return Set.new if ids.empty?

    flags = Sidekiq.redis { |redis| redis.call('MGET', *ids.map { key(provider_id, type, it) }) }
    ids.zip(flags).filter_map { |id, flag| id if flag }.to_set
  end

  def self.key(provider_id, type, external_id) = "#{PREFIX}:#{provider_id}:#{type}:#{external_id}"
end
