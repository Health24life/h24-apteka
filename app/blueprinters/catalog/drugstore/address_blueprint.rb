# frozen_string_literal: true

class Catalog::Drugstore::AddressBlueprint < Blueprinter::Base
  field :address
  field(:latitude) { it.latitude.to_f }
  field(:longitude) { it.longitude.to_f }
end
