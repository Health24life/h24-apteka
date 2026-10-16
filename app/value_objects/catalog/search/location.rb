# frozen_string_literal: true

# Where the providers are asked to look: coordinates in decimal degrees and a radius in metres.
class Catalog::Search::Location < Data.define(:latitude, :longitude, :radius)
  # About a kilometre: enough for a radius of kilometres, and the provider never gets the user's exact position.
  PRECISION = 2

  # The place the front sent, with the configured point or radius for what it left out.
  def self.around(latitude: nil, longitude: nil, radius: nil, config: Catalog::Search.config)
    default = config.location
    new(
      latitude: (latitude || default.latitude).round(PRECISION).to_f,
      longitude: (longitude || default.longitude).round(PRECISION).to_f,
      radius: radius || default.radius
    )
  end
end
