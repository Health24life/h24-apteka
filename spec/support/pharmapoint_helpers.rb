# frozen_string_literal: true

module PharmapointHelpers
  BASE_URL = 'https://partner.test/api'

  def pharmapoint_fixture(name) = Rails.root.join('spec/fixtures/pharmapoint', "#{name}.json").read

  def pharmapoint_config(**overrides)
    Pharmapoint::Config.new(base_url: BASE_URL, api_key: 'secret-key', domain_name: 'h24.test', **overrides)
  end

  # Runs the workers queued inside the block at once, in the order they queue each other.
  def run_jobs(&) = Sidekiq::Testing.inline!(&)

  # The unique locks of the workers are off in specs; a spec that checks them turns them on for its own duration.
  def with_unique_jobs(&)
    SidekiqUniqueJobs.use_config(enabled: true, &)
  ensure
    SidekiqUniqueJobs::Digests.new.delete_by_pattern('*', count: 1000)
  end

  # Makes the code that reads Pharmapoint's settings from the environment see the test ones.
  def use_pharmapoint_config(**overrides)
    config = pharmapoint_config(**overrides)
    allow(Pharmapoint::Config).to receive(:current).and_return(config)
    config
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

  # The limiter's counters and the locks of the on-demand fetch live in Redis, which outlives an example.
  def reset_pharmapoint_redis
    Sidekiq.redis { |redis| redis.scan('MATCH', 'pharmapoint:*') { |key| redis.call('DEL', key) } }
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
