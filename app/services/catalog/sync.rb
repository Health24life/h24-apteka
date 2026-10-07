# frozen_string_literal: true

module Catalog::Sync
  PROVIDER_CODE = 'pharmapoint'

  # A record points at a dictionary entry that has not been imported, and the record itself has no data to create it.
  class MissingReference < StandardError; end

  # The provider's record lacks what is needed to save it at all.
  class MissingData < StandardError; end

  def self.provider = Provider.enabled.find_by!(code: PROVIDER_CODE)
end
