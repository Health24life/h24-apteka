# frozen_string_literal: true

# A class of the ATC classification.
class Pharmapoint::AtcEntry < Data.define(:external_id, :atc_code, :name)
end
