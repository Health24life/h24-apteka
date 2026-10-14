# frozen_string_literal: true

# A month of sync runs of every kind and outcome, failures of single records, and the requests to the provider.
module DevSamples::Operations
  RUNS = 45
  LOGS = 150
  KINDS = %w[dictionaries categories goods_groups drugstores].freeze
  OUTCOMES = [
    [ 'success', 200 ], [ 'success', 200 ], [ 'success', 201 ], [ 'http_error', 422 ], [ 'http_error', 500 ],
    [ 'timeout', nil ], [ 'connection_error', nil ]
  ].freeze
  REQUESTS = [
    %w[refresh GET /goods-group/search], %w[refresh GET /drugstores], %w[search POST /goods/search-in-drugstore],
    %w[search GET /goods-group/typeahead], %w[booking POST /order/store-pick-up-order], %w[booking POST /order/cancel],
    %w[other GET /e-health-recipe/0000-1234-5678-9012]
  ].freeze

  module_function

  def call(provider)
    (RUNS - SyncRun.count).times { run(provider, it) }
    runs = SyncRun.order(:id).to_a
    (LOGS - Provider::RequestLog.count).times { |number| log(provider, number, runs[number % runs.size]) }
  end

  def run(provider, number)
    status = %w[succeeded succeeded completed_with_failures failed][number % 4]
    started = (number * 16).hours.ago
    sync_run = SyncRun.create!(provider:, kind: KINDS[number % KINDS.size], status:, started_at: started,
                               finished_at: started + rand(2..30).minutes, processed_count: rand(50..5_000),
                               failed_count: status == 'completed_with_failures' ? 2 : 0,
                               error_message: ('Faraday::TimeoutError: execution expired' if status == 'failed'))
    failures(sync_run) if sync_run.completed_with_failures?
  end

  def failures(sync_run)
    sync_run.failures.create!(entity_type: 'Catalog::Goods::Group', external_id: "gg-#{sync_run.id}",
                              error_class: 'KeyError', message: 'key not found: "name"',
                              payload: { 'id' => sync_run.id })
    sync_run.failures.create!(entity_type: 'Catalog::Goods', external_id: "g-#{sync_run.id}",
                              error_class: 'ActiveRecord::RecordInvalid', message: 'Назва не може бути порожнім')
  end

  def log(provider, number, sync_run)
    category, http_method, path = REQUESTS[number % REQUESTS.size]
    outcome, status = OUTCOMES[number % OUTCOMES.size]
    refresh = category == 'refresh'
    Provider::RequestLog.create!(
      provider:, category:, http_method:, path:, outcome:, response_status: status, duration_ms: rand(40..3_000),
      sync_run: (sync_run if refresh), attempt: status ? 1 : rand(1..3), created_at: (number * 3).hours.ago,
      error_class: ('Faraday::TimeoutError' unless status), **bodies(category, number)
    )
  end

  def bodies(category, number)
    return { query: { 'q' => 'нурофен', 'page' => number % 5 } } unless category == 'booking'

    { request_body: { 'phone' => format('3805012%05d', number), 'first_name' => 'Олена' },
      response_body: { 'order_number' => "PP#{100_000 + number}" } }
  end
end
