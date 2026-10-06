# frozen_string_literal: true

# A record can only be ordered through a provider that holds a link to it: without the link there is no ID to hand
# to that provider. The provider is read from the validated record.
class ServedByProviderValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    provider = record.provider
    return if value.nil? || provider.nil? || value.provider_links.exists?(provider:)

    record.errors.add(attribute, :not_served_by_provider)
  end
end
