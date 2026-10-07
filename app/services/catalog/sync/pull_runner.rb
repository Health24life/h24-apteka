# frozen_string_literal: true

# Fetches one record from the provider and saves it the way a pass would. Every fetch has a run of its own in the
# journal, so a failure is seen there.
class Catalog::Sync::PullRunner
  def self.call(type, external_id, user_id: nil) = new(type, external_id, user_id).call

  def initialize(type, external_id, user_id)
    @type = type.to_sym
    @external_id = external_id
    @user_id = user_id
  end

  def call
    provider = Catalog::Sync.provider
    tracker = Catalog::Sync::RunTracker.pull(provider:, kind: Catalog::Sync::Pull::TYPES.fetch(@type)[:kind])
    fetch_and_save(provider, tracker)
    tracker.finish!
  rescue *Catalog::Sync::StepRunner::LOST_STEP_ERRORS, Pharmapoint::ConfigurationError => e
    # The provider will not give the record; another try would not change that, so the journal has the last word.
    tracker&.fail!(e.message)
  rescue StandardError => e
    tracker&.fail!(e.message)
    raise
  end

  private

  def fetch_and_save(provider, tracker)
    client = Pharmapoint::Client.new(provider:, purpose: :refresh, user_id: @user_id, sync_run: tracker.run,
                                     attempt: SidekiqMiddleware::JobAttempt.current)
    linker = Catalog::Sync::Linker.new(provider)
    if @type == :goods_group
      pull_goods_group(client, linker, tracker)
    else
      pull_drugstore(client, linker, tracker)
    end
  end

  def pull_goods_group(client, linker, tracker)
    record = client.goods_group(@external_id)
    tracker.guard('Catalog::Goods::Group', @external_id, record) do
      Catalog::Sync::Savers::GoodsGroup.new(linker, tracker).call(record)
    end
  end

  def pull_drugstore(client, linker, tracker)
    record = client.drugstore(@external_id)
    tracker.guard('Catalog::Drugstore', @external_id, record) do
      Catalog::Sync::Savers::Drugstore.new(linker).call(record)
      tracker.processed!
    end
  end
end
