# frozen_string_literal: true

# One query of a search request: the text, the page of goods groups and the place to look around.
class Catalog::Search::Query < Data.define(:text, :page, :location)
end
