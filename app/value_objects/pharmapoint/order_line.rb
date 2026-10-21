# frozen_string_literal: true

# A line of goods the partner is asked the price and stock of: its id at the partner and the whole packs wanted.
class Pharmapoint::OrderLine < Data.define(:external_id, :quantity); end
