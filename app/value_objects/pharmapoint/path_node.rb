# frozen_string_literal: true

# A step of the path from the root of the category tree down to a category.
class Pharmapoint::PathNode < Data.define(:external_id, :name)
end
