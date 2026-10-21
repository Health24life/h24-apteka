# frozen_string_literal: true

# Opaque keys of the rows of the search: the same for the same goods group or SKU of a provider, different across
# providers, and telling the front nothing of the provider or its ids. They are keyed with the application secret, so
# they cannot be worked back to the provider's ids.
module Catalog::Search::Ref
  LENGTH = 16

  def self.for(*parts) = OpenSSL::HMAC.hexdigest('SHA256', key, parts.join(':')).first(LENGTH)

  def self.key = @key ||= Rails.application.key_generator.generate_key('catalog_search_ref')
end
