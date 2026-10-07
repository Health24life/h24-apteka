# frozen_string_literal: true

# The six dictionaries of the provider's catalog.
class Pharmapoint::Dictionaries < Data.define(:forms, :measures, :price_groups, :temperature_modes, :restrictions,
                                              :brands)
end
