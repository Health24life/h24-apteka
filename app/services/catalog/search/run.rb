# frozen_string_literal: true

# Runs a search request: every query in every provider the search asks, one after another within the time the request
# may take, never repeating a call. The goods of the providers are listed in the order of the providers, each in its
# own order; a page is page k of every provider. The deadline covers the providers only: the catalog is asked and what
# they found is queued for the sync once every provider has answered, and the answer does not wait for the save.
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
    answers = queries.map { ask_all(it, deadline) }
    queries.each_with_index.map { |query, index| result(query, answers.fetch(index)) }
      .tap { Catalog::Search::Metrics.results(it) }
  end

  private

  def ask_all(query, deadline) = @adapters.map { [ it, ask(it, query, deadline) ] }

  def ask(adapter, query, deadline)
    adapter.call(query, time_left: deadline - now).tap { Catalog::Search::Metrics.answer(adapter.provider.code, it) }
  end

  def result(query, answers)
    pages, failures = split(answers)
    provider_pages = pages.map(&:last)
    Catalog::Search::Result.new(
      query: query.text,
      status: status(pages, failures),
      page: query.page,
      per_page: provider_pages.sum(&:per_page),
      total_groups: provider_pages.sum(&:total_groups),
      has_more: provider_pages.any?(&:has_more),
      goods: pages.flat_map { |adapter, page| goods(adapter.provider, page) },
      failures:
    )
  end

  def split(answers)
    # @type var pages: Array[[ Catalog::Search::Adapters::_Adapter, Catalog::Search::ProviderPage ]]
    pages = []
    # @type var failures: Array[Catalog::Search::Failure]
    failures = []
    answers.each do |adapter, answer|
      case answer
      when Catalog::Search::ProviderPage then pages << [ adapter, answer ]
      else failures << answer
      end
    end
    [ pages, failures ]
  end

  def status(pages, failures)
    return 'unavailable' if pages.empty?

    failures.empty? ? 'ok' : 'partial'
  end

  # The hits the catalog shows; the sync then gets the page with the SKU links the catalog was just asked for.
  def goods(provider, page)
    local = Catalog::Search::LocalGoods.new(provider)
    local.call(page.hits).tap { hand_off(provider, page, local.goods_links) }
  end

  def hand_off(provider, page, goods_links)
    return if page.records.none?

    Catalog::Sync::Pulls::EnqueueFound.call(provider:, found: page.records, user_id: @user_id, goods_links:)
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
