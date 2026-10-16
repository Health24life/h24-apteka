# frozen_string_literal: true

# The answer to one query: the goods of all providers that answered, the page of goods groups, and the providers that
# did not. The status is `ok` when all answered, `partial` when some did and `unavailable` when none did.
class Catalog::Search::Result < Data.define(
  :query,
  :status,
  :unavailable_providers,
  :page,
  :per_page,
  :total_groups,
  :has_more,
  :goods,
  :failures
)
  def unavailable? = status == 'unavailable'
end
