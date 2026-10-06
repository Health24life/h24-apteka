# frozen_string_literal: true

# A record can only be ordered through a provider that holds a link to it: without the link there is no ID to hand
# to that provider.
module ProviderServed
  extend ActiveSupport::Concern

  private

  def validate_served_by_provider(attribute, provider)
    record = public_send(attribute)
    return if record.nil? || provider.nil? || record.provider_links.exists?(provider:)

    errors.add(attribute, :not_served_by_provider)
  end
end
