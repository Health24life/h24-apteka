# frozen_string_literal: true

# Queues the fetch of a record the catalog does not have yet, or has only in part. The answer to the user does not wait
# for it. The same record is queued once at a time: the worker's unique lock drops a second request for it.
class Catalog::Sync::Pull
  TYPES = {
    goods_group: { model: Catalog::Goods::Group, kind: 'goods_groups' },
    drugstore: { model: Catalog::Drugstore, kind: 'drugstores' }
  }.freeze

  # Returns what became of the request: :enqueued, :queued_already or :present.
  def self.enqueue(type, external_id, user_id: nil, config: Pharmapoint::Config.current)
    return :present if present?(type, external_id, config)

    queued = Catalog::Sync::PullWorker.perform_async(type.to_s, external_id.to_s, user_id)
    queued ? :enqueued : :queued_already
  end

  def self.present?(type, external_id, config)
    link = linked(type, external_id)
    return false unless link

    stale = link.synced_at < config.stale_record_after.ago
    incomplete = type == :drugstore && link.linkable.incomplete?
    !stale && !incomplete
  end

  def self.linked(type, external_id)
    Provider::Link.find_by(provider: Catalog::Sync.provider, linkable_type: TYPES.fetch(type)[:model].name,
                           external_id: external_id.to_s)
  end
end
