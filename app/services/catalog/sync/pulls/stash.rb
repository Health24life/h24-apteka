# frozen_string_literal: true

# Goods groups as the live search got them, kept for a short while so that their on-demand fetch saves them without
# asking the provider again. The cache may lose an entry at any time: a fetch that misses it asks the provider. A group
# is kept as the provider's JSON, not as a value object, so an entry written before a deploy still reads after it.
class Catalog::Sync::Pulls::Stash
  PREFIX = 'catalog_sync_stash'

  def self.key(provider_id, external_id) = "#{PREFIX}:#{provider_id}:goods_group:#{external_id}"

  # Keeps the groups that are complete enough to be saved from; returns their keys by the provider's id of the group,
  # read the way the rest of the sync reads it.
  def self.write(provider:, records:, config: Catalog::Sync.config)
    stashed = records.filter_map { stashable(provider, it) }
    store(stashed.to_h { |_id, key, record| [ key, record ] }, config.pull.stash_ttl)
    stashed.to_h { |id, key, _record| [ id, key ] }
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { source: 'catalog_sync_stash' })
    {}
  end

  def self.stashable(provider, record)
    group = Pharmapoint::Readers::StashableGoodsGroup.call(record)
    id = group && Pharmapoint::Readers::Base.id_at(group, 'id')
    [ id, key(provider.id, id), group ] if group && id
  end

  def self.store(stashed, ttl)
    Rails.cache.write_multi(stashed.transform_values(&:to_json), expires_in: ttl) if stashed.any?
  end

  def self.read(key)
    json = Rails.cache.read(key)
    JSON.parse(json) if json.is_a?(String)
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { source: 'catalog_sync_stash' })
    nil
  end
end
