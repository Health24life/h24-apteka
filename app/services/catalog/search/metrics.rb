# frozen_string_literal: true

# Counts what the search does, for the metrics declared in config/initializers/yabeda.rb. A failure to count is
# reported and never reaches the search.
module Catalog::Search::Metrics
  # The window the share of on-demand fetches saved without asking the provider again is measured over.
  PULL_WINDOW = 1.hour
  PULL_SOURCES = %w[stash provider].freeze

  module_function

  def results(results)
    measure { results.each { Yabeda.apteka_search.requests_total.increment({ status: outcome(it) }) } }
  end

  def answer(provider, answer)
    measure { Yabeda.apteka_search.provider_answers_total.increment({ provider:, status: answer_status(answer) }) }
  end

  def duration(provider, seconds)
    measure { Yabeda.apteka_search.provider_duration_seconds.measure({ provider: }, seconds) }
  end

  # The block reads what is left; it is not asked when counting fails.
  def share_left(provider)
    measure { Yabeda.apteka_search.rate_limit_share_left.set({ provider: }, yield) }
  end

  # The on-demand fetches of goods groups saved in the last hour, by provider and by where the record came from. Asked
  # provider by provider, so the index of the journal on the provider, the kind and the start serves it.
  def collect_pulls
    measure do
      Provider.find_each do |provider|
        counts = SyncRun.where(provider:, kind: 'goods_groups', started_at: PULL_WINDOW.ago.., status: 'succeeded')
          .where("progress ->> 'mode' = 'pull'")
          .group("progress ->> 'source'")
          .count
        PULL_SOURCES.each do |source|
          Yabeda.apteka_search.pulls.set({ provider: provider.code, source: }, counts.fetch(source, 0))
        end
      end
    end
  end

  def outcome(result)
    failures = result.failures
    return 'busy' if result.unavailable? && failures.any? && failures.all?(&:rate_limited?)
    return result.status unless result.status == 'ok'

    result.goods.empty? ? 'empty' : 'ok'
  end

  def answer_status(answer)
    case answer
    when Catalog::Search::ProviderPage then answer.hits.empty? ? 'empty' : 'ok'
    else answer.rate_limited? ? 'busy' : 'unavailable'
    end
  end

  def measure(&) = Rails.error.handle(context: { source: 'catalog_search_metrics' }, &)
end
