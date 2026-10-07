# frozen_string_literal: true

# How a release form is packed.
class Pharmapoint::Pack < Data.define(:unit_name, :quantity_in_pack, :quantity_unit_in_pack, :quantity_in_unit)
end
