# frozen_string_literal: true

# The providers a search asks, each with the adapter that searches it. A provider is asked when it is enabled, the
# configuration allows its search and an adapter for its code exists; a provider of our own has none yet. Turning the
# search of a provider off leaves its sync and on-demand fetch running.
module Catalog::Search::Adapters
  BY_CODE = { 'pharmapoint' => Pharmapoint::Search }.freeze

  # The adapters in the order of the providers' ids, the order their goods are listed in.
  def self.build(user_id: nil, config: Catalog::Search.config)
    codes = config.providers & BY_CODE.keys
    return [] if codes.empty?

    Provider.enabled.where(code: codes).order(:id).map { BY_CODE.fetch(it.code).new(provider: it, user_id:) }
  end
end
