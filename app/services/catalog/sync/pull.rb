# frozen_string_literal: true

# Queues the fetch of a record the catalog does not have yet, or has only in part. The answer to the user does not wait
# for it. The same record of the same provider is queued once at a time: the worker's unique lock drops a second
# request for it.
class Catalog::Sync::Pull
  TYPES = {
    goods_group: { model: Catalog::Goods::Group, kind: 'goods_groups' },
    drugstore: { model: Catalog::Drugstore, kind: 'drugstores' }
  }.freeze
  COOLDOWN_PREFIX = 'catalog_sync_pull_cooldown'

  # A goods group of the live answer: its id and the ids of its SKU, with the record as the provider gave it.
  class Found < Data.define(:external_id, :goods_ids, :record); end

  # A goods group the catalog already has, as far as the decision to fetch it needs.
  class Known < Data.define(:synced_at, :withdrawn, :hidden); end

  # Returns what became of the request: :enqueued, :queued_already or :present. Without a provider the job carries
  # none and the worker takes the default one, as the jobs queued before providers were told apart do.
  def self.enqueue(type, external_id, user_id: nil, provider: nil, config: Pharmapoint::Config.current)
    return :present if present?(type, external_id, config, provider || Catalog::Sync.provider)

    worker = Catalog::Sync::PullWorker
    queued = if provider
               worker.perform_async(type.to_s, external_id.to_s, user_id, provider.id)
    else
               worker.perform_async(type.to_s, external_id.to_s, user_id)
    end
    queued ? :enqueued : :queued_already
  end

  # Queues the goods groups of a page of the live search that the catalog lacks, has stale or withdrawn, or that bring
  # a SKU it lacks; the groups are kept in the stash, so the fetch may save them without asking the provider again. The
  # page is checked in two queries, not two per group. A group an operator hid, or one whose fetch failed for good a
  # moment ago, is left alone. Returns what became of each group by its id: :enqueued, :queued_already, :present,
  # :hidden or :cooling_down. A failure is reported and does not reach the search.
  def self.enqueue_found(provider:, found:, user_id: nil, config: Pharmapoint::Config.current)
    return report(ActiveRecord::RecordNotFound.new("Provider #{provider.code} is disabled")) unless provider.active?

    groups = found.filter_map { read_found(it) }.uniq(&:external_id)
    outcomes = decide(provider, groups, config)
    outcomes.merge(queue_found(provider, groups.select { outcomes[it.external_id] == :wanted }, user_id, config))
  rescue StandardError => e
    report(e)
  end

  def self.queue_found(provider, groups, user_id, config)
    keys = Catalog::Sync::Stash.write(provider:, records: groups.map(&:record), config:)
    groups.to_h do |group|
      id = group.external_id
      queued = Catalog::Sync::PullWorker.perform_async('goods_group', id, user_id, provider.id, keys[id])
      [ id, queued ? :enqueued : :queued_already ]
    end
  end

  def self.report(error)
    Rails.error.report(error, handled: true, context: { source: 'catalog_sync_pull' })
    {}
  end

  def self.read_found(record)
    return unless record.is_a?(Hash)

    external_id = Pharmapoint::Readers::Base.id_at(record, 'id')
    return unless external_id

    goods_ids = Pharmapoint::Readers::Base.list_at(record, 'release_forms').filter_map do |form|
      Pharmapoint::Readers::Base.id_at(form, 'id') if form.is_a?(Hash)
    end
    Found.new(external_id:, goods_ids:, record:)
  end

  def self.decide(provider, groups, config)
    ids = groups.map(&:external_id)
    known = known_groups(provider, ids)
    linked_goods = linked_goods(provider, groups.flat_map(&:goods_ids))
    cooling = cooling_down(provider, :goods_group, ids)
    groups.to_h do |group|
      [ group.external_id, decision(group, known[group.external_id], linked_goods, cooling, config) ]
    end
  end

  def self.decision(group, known, linked_goods, cooling, config)
    return :hidden if known&.hidden
    return :cooling_down if cooling.include?(group.external_id)
    return :wanted unless known && current?(known, config)

    group.goods_ids.all? { linked_goods.include?(it) } ? :present : :wanted
  end

  def self.current?(known, config) = !known.withdrawn && known.synced_at >= config.stale_record_after.ago

  def self.known_groups(provider, ids)
    rows = Catalog::Goods::Group.joins(:provider_links)
                                .where(provider_links: { provider_id: provider.id, external_id: ids })
                                .pluck('provider_links.external_id', 'provider_links.synced_at', :withdrawn, :hidden)
    rows.to_h { |id, synced_at, withdrawn, hidden| [ id, Known.new(synced_at:, withdrawn:, hidden:) ] }
  end

  def self.linked_goods(provider, ids)
    return Set.new if ids.empty?

    Provider::Link.where(provider:, linkable_type: Catalog::Goods.name, external_id: ids).pluck(:external_id).to_set
  end

  # A record whose fetch failed for good is not queued again for a while: the same failure would only repeat.
  def self.cool_down!(provider_id, type, external_id, config: Pharmapoint::Config.current)
    Sidekiq.redis do |redis|
      redis.call('SET', cooldown_key(provider_id, type, external_id), '1', 'EX', config.pull_cooldown.to_i)
    end
  end

  def self.cooling_down(provider, type, ids)
    return Set.new if ids.empty?

    flags = Sidekiq.redis { |redis| redis.call('MGET', *ids.map { cooldown_key(provider.id, type, it) }) }
    ids.zip(flags).filter_map { |id, flag| id if flag }.to_set
  end

  def self.cooldown_key(provider_id, type, external_id) = "#{COOLDOWN_PREFIX}:#{provider_id}:#{type}:#{external_id}"

  def self.present?(type, external_id, config, provider = Catalog::Sync.provider)
    link = linked(type, external_id, provider)
    return false unless link

    stale = link.synced_at < config.stale_record_after.ago
    incomplete = type == :drugstore && link.linkable.incomplete?
    !stale && !incomplete
  end

  def self.linked(type, external_id, provider = Catalog::Sync.provider)
    Provider::Link.find_by(provider:, linkable_type: TYPES.fetch(type)[:model].name, external_id: external_id.to_s)
  end
end
