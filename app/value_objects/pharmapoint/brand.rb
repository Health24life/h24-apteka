# frozen_string_literal: true

# The brand of a drugstore chain.
class Pharmapoint::Brand < Data.define(:external_id, :name, :image_path)
end
