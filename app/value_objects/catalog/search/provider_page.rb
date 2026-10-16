# frozen_string_literal: true

# What one provider answered to one query: the SKU it found, how many goods groups it has for the text, and the records
# of the groups as it gave them, for the catalog to save without asking again.
class Catalog::Search::ProviderPage < Data.define(:provider, :hits, :per_page, :total_groups, :has_more, :records)
end
