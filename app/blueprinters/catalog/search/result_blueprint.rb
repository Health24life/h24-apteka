# frozen_string_literal: true

class Catalog::Search::ResultBlueprint < Blueprinter::Base
  fields :query, :status, :page, :per_page, :total_groups, :has_more

  association :goods, blueprint: Catalog::Search::GoodsBlueprint
end
