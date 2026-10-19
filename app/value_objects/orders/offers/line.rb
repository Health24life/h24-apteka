# frozen_string_literal: true

# What a drugstore has of one SKU of the catalog: whether it covers the quantity asked, its price in the drugstore and
# the whole packs it has.
class Orders::Offers::Line < Data.define(:goods_id, :fulfilled, :price, :available_quantity); end
