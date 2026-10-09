# frozen_string_literal: true

# A release form (SKU) of a goods group.
class Pharmapoint::Goods < Data.define(:external_id, :name, :morion_code, :card, :pack, :references)
end
