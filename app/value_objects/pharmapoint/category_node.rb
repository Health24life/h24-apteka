# frozen_string_literal: true

# A node of the category tree with the nodes below it.
class Pharmapoint::CategoryNode < Data.define(:external_id, :name, :children)
end
