# frozen_string_literal: true

# A drugstore's live answer for the goods asked, in the terms of the catalog. `drugstore_id` is nil for a drugstore the
# directory does not have. `lines` is nil when the provider told nothing of the goods, which is no data rather than a
# drugstore without them; a SKU missing from `lines` is not covered.
class Orders::Offers::DrugstoreOffer < Data.define(
  :drugstore_id,
  :distance,
  :open_now,
  :opens_at,
  :closes_at,
  :round_the_clock,
  :lines
)
  def self.unknown(drugstore_id)
    new(
      drugstore_id:,
      distance: nil,
      open_now: nil,
      opens_at: nil,
      closes_at: nil,
      round_the_clock: false,
      lines: nil
    )
  end

  def known? = !lines.nil?

  def line_for(goods_id) = lines&.find { it.goods_id == goods_id }
end
