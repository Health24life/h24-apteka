# frozen_string_literal: true

# A drugstore of the list for a SKU: the directory's data, and live the distance, whether it is open, when it opens if
# not, the SKU's price in the drugstore in hryvnias as a string, and the whole packs it has.
class Orders::Offers::NearbyDrugstoreBlueprint < Catalog::DrugstoreBlueprint
  fields :distance, :open_now, :opens_at

  field(:goods) do |row|
    { price: ActiveSupport::NumberHelper.number_to_rounded(row.price, precision: 2), available_quantity: row.available_quantity }
  end
end
