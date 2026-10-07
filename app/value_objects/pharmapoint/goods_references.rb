# frozen_string_literal: true

# The dictionary entries a release form points at, by the provider's ids.
class Pharmapoint::GoodsReferences < Data.define(:form, :measure, :price_group, :temperature_mode,
                                                 :adult_restriction, :child_restriction, :diabetic_restriction,
                                                 :driver_restriction, :pregnant_and_lactating_restriction)
end
