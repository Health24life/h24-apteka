# frozen_string_literal: true

# A point the drugstore directory is fetched around: coordinates and a radius in metres.
class Pharmapoint::SearchPoint < Data.define(:latitude, :longitude, :radius); end
