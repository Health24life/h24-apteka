# frozen_string_literal: true

# A line of an order as the partner keeps it: the partner's id of the goods and the quantity.
class Pharmapoint::PartnerOrderLine < Data.define(:goods_external_id, :quantity); end
