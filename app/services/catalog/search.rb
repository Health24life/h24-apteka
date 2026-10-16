# frozen_string_literal: true

# The live search of goods: it asks the providers, never the local catalog, and hands what they found to the sync.
module Catalog::Search
  class << self
    # The settings of the search, built from the environment at boot by config/initializers/settings.rb.
    attr_accessor :config
  end
end
