# frozen_string_literal: true

# A drugstore of «Мої аптеки» as a drugstore is shown everywhere else, whether the directory still shows it, and when
# it was added.
class Favorites::DrugstoreBlueprint < Catalog::DrugstoreBlueprint
  field :available?, name: :available
  field(:added_at) { |row| row.added_at.iso8601 }
end
