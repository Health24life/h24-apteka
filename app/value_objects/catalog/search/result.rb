# frozen_string_literal: true

# The answer to one query: the goods of all providers that answered, the page of goods groups, and the providers that
# did not. The status is `ok` when all answered, `partial` when some did and `unavailable` when none did.
class Catalog::Search::Result < Data.define(
  :query,
  :status,
  :page,
  :per_page,
  :total_groups,
  :has_more,
  :goods,
  :failures
)
  def unavailable? = status == 'unavailable'

  # No provider answered, and every one of them refused for its request limit.
  def busy? = unavailable? && failures.any? && failures.all?(&:rate_limited?)

  # The earliest a provider that refused for its limit lets the search try again.
  def retry_after = failures.filter_map(&:retry_after).min
end
