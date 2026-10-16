# frozen_string_literal: true

# Fetching on demand the records the catalog lacks: queueing one record or a page of the live search, the stash of the
# live answer, the pause after a failure, the fetch itself and the retention of its runs.
module Catalog::Sync::Pulls
  TYPES = {
    goods_group: { model: Catalog::Goods::Group, kind: 'goods_groups' },
    drugstore: { model: Catalog::Drugstore, kind: 'drugstores' }
  }.freeze
end
