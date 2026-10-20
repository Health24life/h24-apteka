# frozen_string_literal: true

# A drugstore of the list for a SKU: the directory's data, and live the distance, whether it is open, the moment it
# opens if not, the SKU's price in the drugstore in hryvnias as a string, and the whole packs it has.
class Orders::Offers::NearbyDrugstoreBlueprint < Catalog::DrugstoreBlueprint
  fields :distance, :open_now

  field(:opens_at) { |row| row.opens_at&.iso8601 }

  field(:goods) do |row|
    { price: ActiveSupport::NumberHelper.number_to_rounded(row.price, precision: 2), available_quantity: row.available_quantity }
  end
end
