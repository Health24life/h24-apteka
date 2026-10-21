# frozen_string_literal: true

# A drugstore's answer for the goods asked. `items` is nil when the partner told nothing of them: that is no data, not
# a drugstore without the goods.
class Pharmapoint::Offer < Data.define(:drugstore_external_id, :distance, :today_hours, :items); end
