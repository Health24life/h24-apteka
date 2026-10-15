# frozen_string_literal: true

module PharmapointHelpers
  BASE_URL = 'https://partner.test/api'

  def pharmapoint_fixture(name) = Rails.root.join('spec/fixtures/pharmapoint', "#{name}.json").read

  # The partner settings of a spec: the test connection with what the spec changes, as nested hashes of settings.
  def pharmapoint_config(**overrides)
    Pharmapoint::Config.new.configure do |config|
      config.update(connection: { base_url: BASE_URL, api_key: 'secret-key', domain_name: 'h24.test' })
      config.update(overrides)
    end
  end

  def sync_config(**overrides) = Catalog::Sync::Config.new.configure { it.update(overrides) }

  # Runs the workers queued inside the block at once, in the order they queue each other.
  def run_jobs(&) = Sidekiq::Testing.inline!(&)

  # The unique locks of the workers are off in specs; a spec that checks them turns them on for its own duration.
  def with_unique_jobs(&)
    SidekiqUniqueJobs.use_config(enabled: true, &)
  ensure
    SidekiqUniqueJobs::Digests.new.delete_by_pattern('*', count: 1000)
  end

  # Makes the code that reads the partner settings see the test ones in place of those built from the environment.
  def use_pharmapoint_config(**overrides)
    config = pharmapoint_config(**overrides)
    allow(Pharmapoint).to receive(:config).and_return(config)
    config
  end

  def use_sync_config(**overrides)
    config = sync_config(**overrides)
    allow(Catalog::Sync).to receive(:config).and_return(config)
    config
  end

  # The first goods group of a fixture with an instruction in every SKU, complete enough to be stashed.
  def complete_goods_group(fixture = 'goods_group_search')
    data = JSON.parse(pharmapoint_fixture(fixture))['data']
    group = data.is_a?(Array) ? data.first : data
    group['release_forms'].each { |form| form['instruction'] ||= '<p>Склад</p>' }
    group
  end

  def pharmapoint_url(path) = "#{BASE_URL}/#{path}"

  def stub_pharmapoint(path, fixture: nil, query: nil, **answer)
    stub = stub_request(:get, pharmapoint_url(path))
    stub = stub.with(query:) if query
    stub.to_return(pharmapoint_answer(fixture, **answer))
  end

  def pharmapoint_answer(fixture, body: nil, status: 200, headers: {})
    { status:, body: body || pharmapoint_fixture(fixture),
      headers: { 'Content-Type' => 'application/json' }.merge(headers) }
  end

  # The limiter's counters and the pauses of the on-demand fetch live in Redis, which outlives an example.
  def reset_pharmapoint_redis
    Sidekiq.redis do |redis|
      %w[pharmapoint:* catalog_sync_pull_cooldown:*].each do |pattern|
        redis.scan('MATCH', pattern) { |key| redis.call('DEL', key) }
      end
    end
  end
end

RSpec.configure do |config|
  config.include PharmapointHelpers
  # The limiter keeps its counters in Redis, which outlive an example; only specs that go through it clean up.
  config.define_derived_metadata(file_path: %r{spec/(services/(pharmapoint|catalog)|workers|lib)/}) do |metadata|
    metadata[:partner_calls] = true
  end
  config.before(:each, :partner_calls) { reset_pharmapoint_redis }
end
