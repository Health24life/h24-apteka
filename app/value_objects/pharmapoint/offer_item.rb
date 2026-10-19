# frozen_string_literal: true

# What a drugstore has of one line asked: whether it covers the line, its price in the drugstore and the quantity.
class Pharmapoint::OfferItem < Data.define(:goods_external_id, :fulfilled, :price, :quantity); end
