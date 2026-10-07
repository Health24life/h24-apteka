# frozen_string_literal: true

# The ATC class of a goods group with the classes above it, from the root down.
class Pharmapoint::AtcClass < Data.define(:external_id, :atc_code, :name, :ancestors)
end
