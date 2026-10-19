# frozen_string_literal: true

# The adapter that asks a provider for the live prices and stock of drugstores, by the provider's code. A provider with
# no adapter, such as one of our own, gives no offers.
module Orders::Offers::Adapters
  BY_CODE = { 'pharmapoint' => Pharmapoint::Offers }.freeze

  def self.for(provider, user_id: nil) = BY_CODE[provider.code]&.new(provider:, user_id:)
end
