# frozen_string_literal: true

# Saves one record the way a pass would: from the stash the live search left, or else fetched from the provider. Every
# fetch has a run of its own in the journal, so a failure is seen there. A run is opened only once the record can be
# had: a provider that is off or a used-up request limit leaves no failed run behind.
class Catalog::Sync::Pulls::Runner
  def self.call(type, external_id, user_id: nil, provider_id: nil, stash_key: nil)
    new(type, external_id, user_id, provider_id, stash_key).call
  end

  # The retries are spent: the record is not queued again for a while.
  def self.give_up(type, external_id, _user_id = nil, provider_id = nil)
    provider = find_provider(provider_id)
    Catalog::Sync::Pulls::Cooldown.pause!(provider.id, type, external_id) if provider
  end

  # A job queued before providers were told apart carries none and belongs to the default one.
  def self.find_provider(provider_id)
    Provider.enabled.find_by(provider_id ? { id: provider_id } : { code: Catalog::Sync::PROVIDER_CODE })
  end

  def initialize(type, external_id, user_id, provider_id, stash_key)
    @type = type.to_sym
    @external_id = external_id
    @user_id = user_id
    @provider_id = provider_id
    @stash_key = stash_key
  end

  def call
    provider = self.class.find_provider(@provider_id)
    unless provider
      Rails.error.report(
        ActiveRecord::RecordNotFound.new("No enabled provider #{@provider_id} for #{@external_id}"),
        handled: true,
        context: { source: 'catalog_sync_pull' }
      )
      return
    end

    stash_key = @stash_key
    stashed = @type == :goods_group && stash_key ? Catalog::Sync::Pulls::Stash.read(stash_key) : nil
    stashed ? save_stashed(provider, stashed) : fetch_and_save(provider)
  end

  private

  def save_stashed(provider, record)
    track(provider, 'stash') do |tracker|
      group = Pharmapoint::Readers::GoodsGroups.one('data' => record)
      Catalog::Sync::Savers::GoodsGroup.new(Catalog::Sync::Linker.new(provider), tracker).call([ group ])
    end
  end

  def fetch_and_save(provider)
    limiter = Pharmapoint::RateLimiter.new
    wait = limiter.wait_time
    raise Pharmapoint::RateLimited, wait if wait.positive?

    track(provider, 'provider') do |tracker|
      client = Pharmapoint::Client.new(
        provider:,
        purpose: :refresh,
        user_id: @user_id,
        sync_run: tracker.run,
        attempt: SidekiqMiddleware::JobAttempt.current,
        rate_limiter: limiter
      )
      linker = Catalog::Sync::Linker.new(provider)
      @type == :goods_group ? pull_goods_group(client, linker, tracker) : pull_drugstore(client, linker, tracker)
    end
  end

  def track(provider, source)
    tracker = Catalog::Sync::RunTracker.pull(provider:, kind: Catalog::Sync::Pulls::TYPES.fetch(@type)[:kind], source:)
    yield tracker
    tracker.finish!
    pause(provider) unless tracker.run.succeeded?
  rescue *Catalog::Sync::StepRunner::LOST_STEP_ERRORS, Pharmapoint::ConfigurationError => e
    # The provider will not give the record; another try would not change that, so the journal has the last word.
    tracker&.fail!(e.message)
    pause(provider)
  rescue StandardError => e
    tracker&.fail!(e.message)
    raise
  end

  def pause(provider) = Catalog::Sync::Pulls::Cooldown.pause!(provider.id, @type, @external_id)

  def pull_goods_group(client, linker, tracker)
    Catalog::Sync::Savers::GoodsGroup.new(linker, tracker).call([ client.goods_group(@external_id) ])
  end

  def pull_drugstore(client, linker, tracker)
    record = client.drugstore(@external_id)
    tracker.guard('Catalog::Drugstore', @external_id, record) do
      Catalog::Sync::Savers::Drugstore.new(linker).call(record)
      tracker.processed!
    end
  end
end
