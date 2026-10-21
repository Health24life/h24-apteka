# frozen_string_literal: true

# The live search of goods: it asks the providers, never the local catalog, and hands what they found to the sync.
module Catalog::Search
  # A part of a search request that cannot be searched; the code names it for the answer.
  class Invalid < StandardError
    attr_reader :code

    def initialize(code)
      super(code.to_s)
      @code = code
    end
  end

  class << self
    # The settings of the search, built from the environment at boot by config/initializers/settings.rb.
    attr_accessor :config
  end
end
