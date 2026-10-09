# frozen_string_literal: true

# A category a goods group is in, with the path to it from the root.
class Pharmapoint::GroupCategory < Data.define(:external_id, :name, :path)
end
