# frozen_string_literal: true

# The adapter that makes an order at a provider and finds it there again, by the provider's code.
module Orders::Bookings::Adapters
  BY_CODE = { 'pharmapoint' => Pharmapoint::Bookings }.freeze

  def self.for(provider, user_id: nil) = BY_CODE[provider.code]&.new(provider:, user_id:)
end
