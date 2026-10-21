# frozen_string_literal: true

# «Мої товари» and «Мої аптеки» of an account. A list keeps SKU or drugstores of the catalog; one that an operator hides
# or the sync withdraws later stays in it, marked unavailable.
module Favorites
  # Records each list holds. It is counted before the insert, with no lock: additions sent at the same moment may each
  # see room and pass it together, by as many as were sent at once. A soft bound, not a rule of the business.
  LIMIT = 100

  # A list: the model of its records, the catalog model it keeps, the column that points there and the code of the
  # answer when the catalog does not show the record.
  class Kind < Data.define(:model, :target, :key, :not_found); end

  GOODS = Kind.new(model: Favorite::Goods, target: Catalog::Goods, key: :goods_id, not_found: :goods_not_found)
  DRUGSTORES = Kind.new(
    model: Favorite::Drugstore,
    target: Catalog::Drugstore,
    key: :drugstore_id,
    not_found: :drugstore_not_found
  )
end
