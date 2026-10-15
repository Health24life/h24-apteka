# frozen_string_literal: true

# Queues the fetch of one record the catalog does not have yet, or has only in part. The answer to the user does not
# wait for it. The same record of the same provider is queued once at a time: the worker's unique lock drops a second
# request for it.
class Catalog::Sync::Pulls::Enqueue
  # Returns what became of the request: :enqueued, :queued_already or :present. Without a provider the job carries
  # none and the worker takes the default one, as the jobs queued before providers were told apart do.
  def self.call(type, external_id, user_id: nil, provider: nil, config: Catalog::Sync.config)
    new(type, external_id.to_s, user_id, provider, config).call
  end

  def initialize(type, external_id, user_id, provider, config)
    @type = type
    @external_id = external_id
    @user_id = user_id
    @provider = provider
    @config = config
  end

  def call
    return :present if present?

    queue ? :enqueued : :queued_already
  end

  private

  def queue
    worker = Catalog::Sync::PullWorker
    provider = @provider
    return worker.perform_async(@type.to_s, @external_id, @user_id) unless provider

    worker.perform_async(@type.to_s, @external_id, @user_id, provider.id)
  end

  def present?
    link = Provider::Link.find_by(provider: @provider || Catalog::Sync.provider, external_id: @external_id,
                                  linkable_type: Catalog::Sync::Pulls::TYPES.fetch(@type)[:model].name)
    return false unless link

    stale = link.synced_at < @config.stale_record_after.ago
    incomplete = @type == :drugstore && link.linkable.incomplete?
    !stale && !incomplete
  end
end
