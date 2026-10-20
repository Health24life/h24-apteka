# frozen_string_literal: true

# Queues the goods groups of a page of the live search that the catalog lacks, has stale or withdrawn, or that bring a
# SKU it lacks; the groups are kept in the stash, so the fetch may save them without asking the provider again. The
# page is checked in two queries, not two per group. A group an operator hid, or one whose fetch failed for good a
# moment ago, is left alone. A failure is reported and does not reach the search.
class Catalog::Sync::Pulls::EnqueueFound
  # A goods group of the live answer: its id and the ids of its SKU, with the record as the provider gave it.
  class Found < Data.define(:external_id, :goods_ids, :record); end

  # A goods group the catalog already has, as far as the decision to fetch it needs.
  class Known < Data.define(:synced_at, :withdrawn, :hidden); end

  # Returns what became of each group by its id: :enqueued, :queued_already, :present, :hidden or :paused. The links of
  # SKU the caller has already looked up, linked or not by the provider's id, are not looked up again.
  def self.call(provider:, found:, user_id: nil, goods_links: {}, config: Catalog::Sync.config)
    new(provider, user_id, goods_links, config).call(found)
  end

  def initialize(provider, user_id, goods_links, config)
    @provider = provider
    @user_id = user_id
    @goods_links = goods_links
    @config = config
  end

  def call(found)
    return report(ActiveRecord::RecordNotFound.new("Provider #{@provider.code} is disabled")) unless @provider.active?

    groups = found.filter_map { read(it) }.uniq(&:external_id)
    outcomes = decide(groups)
    outcomes.merge(queue(groups.select { outcomes[it.external_id] == :wanted }))
  rescue StandardError => e
    report(e)
  end

  private

  def read(record)
    return unless record.is_a?(Hash)

    external_id = Pharmapoint::Readers::Base.id_at(record, 'id')
    return unless external_id

    goods_ids = Pharmapoint::Readers::Base.list_at(record, 'release_forms').filter_map do |form|
      Pharmapoint::Readers::Base.id_at(form, 'id') if form.is_a?(Hash)
    end
    Found.new(external_id:, goods_ids:, record:)
  end

  def decide(groups)
    ids = groups.map(&:external_id)
    known = known_groups(ids)
    linked_goods = linked_goods(groups.flat_map(&:goods_ids))
    paused = Catalog::Sync::Pulls::Cooldown.paused(@provider.id, :goods_group, ids)
    groups.to_h { [ it.external_id, decision(it, known[it.external_id], linked_goods, paused) ] }
  end

  def decision(group, known, linked_goods, paused)
    return :hidden if known&.hidden
    return :paused if paused.include?(group.external_id)
    return :wanted unless known && current?(known)

    group.goods_ids.all? { linked_goods.include?(it) } ? :present : :wanted
  end

  def current?(known) = !known.withdrawn && known.synced_at >= @config.stale_record_after.ago

  def known_groups(ids)
    rows = Catalog::Goods::Group.joins(:provider_links)
      .where(provider_links: { provider_id: @provider.id, external_id: ids })
      .pluck('provider_links.external_id', 'provider_links.synced_at', :withdrawn, :hidden)
    rows.to_h { |id, synced_at, withdrawn, hidden| [ id, Known.new(synced_at:, withdrawn:, hidden:) ] }
  end

  def linked_goods(ids)
    linked = ids.select { @goods_links[it] }.to_set
    unknown = ids.reject { @goods_links.key?(it) }
    return linked if unknown.empty?

    linked | Provider::Link.where(provider: @provider, linkable_type: Catalog::Goods.name, external_id: unknown)
      .pluck(:external_id)
  end

  # One push for the page: the unique lock still sees every job and leaves no id for the one it drops.
  def queue(groups)
    keys = Catalog::Sync::Pulls::Stash.write(provider: @provider, records: groups.map(&:record), config: @config)
    # @type var args: Array[[ String, String, Integer?, Integer, String? ]]
    args = groups.map { [ 'goods_group', it.external_id, @user_id, @provider.id, keys[it.external_id] ] }
    jids = Catalog::Sync::PullWorker.perform_bulk(args)
    groups.zip(jids).to_h { |group, jid| [ group.external_id, jid ? :enqueued : :queued_already ] }
  end

  def report(error)
    Rails.error.report(error, handled: true, context: { source: 'catalog_sync_pull' })
    {}
  end
end
