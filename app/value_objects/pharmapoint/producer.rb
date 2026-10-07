# frozen_string_literal: true

# The producer of a goods group.
class Pharmapoint::Producer < Data.define(:external_id, :name, :country, :country_code)
end
