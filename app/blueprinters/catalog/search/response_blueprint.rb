# frozen_string_literal: true

# A result per query of the request, in the order of the queries.
class Catalog::Search::ResponseBlueprint < Blueprinter::Base
  association :results, blueprint: Catalog::Search::ResultBlueprint
end
