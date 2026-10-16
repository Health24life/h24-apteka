# frozen_string_literal: true

# Runs a search request: every query in every provider the search asks, one after another within the time the request
# may take, never repeating a call. The goods of the providers are listed in the order of the providers, each in its
# own order; a page is page k of every provider. What they found is handed to the sync to save, and the answer does not
# wait for that.
class Catalog::Search::Run
  def self.call(queries, user_id: nil, config: Catalog::Search.config, adapters: nil)
    new(user_id, config, adapters || Catalog::Search::Adapters.build(user_id:, config:)).call(queries)
  end

  def initialize(user_id, config, adapters)
    @user_id = user_id
    @config = config
    @adapters = adapters
  end

  def call(queries)
    deadline = now + @config.deadline
    queries.map { search(it, deadline) }.tap { Catalog::Search::Metrics.results(it) }
  end

  private

  def search(query, deadline)
    # @type var pages: Array[[ Catalog::Search::Adapters::_Adapter, Catalog::Search::ProviderPage ]]
    pages = []
    # @type var failures: Array[Catalog::Search::Failure]
    failures = []
    @adapters.each do |adapter|
      case (answer = ask(adapter, query, deadline))
      when Catalog::Search::ProviderPage then pages << [ adapter, answer ]
      else failures << answer
      end
    end
    pages.each { |adapter, page| hand_off(adapter.provider, page) }
    result(query, pages, failures)
  end

  def ask(adapter, query, deadline)
    adapter.call(query, time_left: deadline - now).tap { Catalog::Search::Metrics.answer(adapter.provider.code, it) }
  end

  def result(query, pages, failures)
    provider_pages = pages.map(&:last)
    Catalog::Search::Result.new(
      query: query.text,
      status: status(pages, failures),
      page: query.page,
      per_page: provider_pages.sum(&:per_page),
      total_groups: provider_pages.sum(&:total_groups),
      has_more: provider_pages.any?(&:has_more),
      goods: pages.flat_map { |adapter, page| Catalog::Search::LocalGoods.call(adapter.provider, page.hits) },
      failures:
    )
  end

  def status(pages, failures)
    return 'unavailable' if pages.empty?

    failures.empty? ? 'ok' : 'partial'
  end

  def hand_off(provider, page)
    Catalog::Sync::Pulls::EnqueueFound.call(provider:, found: page.records, user_id: @user_id) if page.records.any?
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
