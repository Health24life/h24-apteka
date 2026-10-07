# frozen_string_literal: true

# Where a drugstore is.
class Pharmapoint::Location < Data.define(:address, :city, :state, :latitude, :longitude)
end
