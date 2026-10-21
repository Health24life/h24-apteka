# frozen_string_literal: true

# Metrics of the live search and of the on-demand fetch it feeds. No collector is plugged in yet; one comes with an
# adapter gem and its settings. The search counts in the web process that serves it; the fetch runs in Sidekiq, so its
# numbers are read from the sync journal when a collector collects them rather than counted in another process.
Yabeda.configure do
  group :apteka_search do
    counter :requests_total,
            comment: 'Queries of the search by their outcome: ok, empty, partial, unavailable or busy',
            tags: %i[status]
    counter :provider_answers_total,
            comment: 'Answers of a provider to a query of the search: ok, empty, unavailable or busy',
            tags: %i[provider status]
    histogram :provider_duration_seconds,
              comment: 'How long a provider took to answer a query of the search',
              unit: :seconds,
              tags: %i[provider],
              buckets: [ 0.1, 0.25, 0.5, 1, 2, 3, 4 ]
    gauge :rate_limit_share_left,
          comment: "What is left of the search's share of the provider's request limit in the current minute",
          tags: %i[provider]
    gauge :pulls,
          comment: 'Goods groups fetched on demand in the last hour, by whether the stash of the search held them',
          tags: %i[provider source]
  end

  collect { Catalog::Search::Metrics.collect_pulls }
end

Rails.application.config.after_initialize { Yabeda.configure! unless Yabeda.configured? }
