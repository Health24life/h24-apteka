# frozen_string_literal: true

module Catalog::Sync::Importers
  BY_KIND = {
    'dictionaries' => Catalog::Sync::Importers::Dictionaries, 'categories' => Catalog::Sync::Importers::Categories,
    'goods_groups' => Catalog::Sync::Importers::GoodsGroups, 'drugstores' => Catalog::Sync::Importers::Drugstores
  }.freeze

  def self.for(kind) = BY_KIND.fetch(kind.to_s)
end
