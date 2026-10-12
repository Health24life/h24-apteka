# frozen_string_literal: true

module Catalog::ProviderLinked
  extend ActiveSupport::Concern

  included do
    # A link is saved and validated on its own; the unique indexes guard it when a batch writes it with its record.
    has_many :provider_links, class_name: 'Provider::Link', as: :linkable, inverse_of: :linkable,
                              dependent: :restrict_with_exception, validate: false
    has_many :providers, through: :provider_links
  end

  module ClassMethods
    def find_linked(provider, external_id)
      joins(:provider_links).find_by(provider_links: { provider_id: provider.id, external_id: external_id.to_s })
    end
  end

  def provider_ref(provider)
    provider_links.find_by(provider:)&.external_id
  end
end
