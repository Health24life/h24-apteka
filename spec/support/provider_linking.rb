# frozen_string_literal: true

module ProviderLinking
  # Gives the provider a link to the record, as the import would, unless it already has one.
  def self.link(provider, record)
    ProviderLink.find_by(provider:, linkable: record) ||
      ProviderLink.create!(provider:, linkable: record, external_id: SecureRandom.uuid, synced_at: Time.current)
  end
end
