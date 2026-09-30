# frozen_string_literal: true

module Catalog::ProviderLinked
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ActiveRecord::Base)
    has_many :provider_links, as: :linkable, inverse_of: :linkable, dependent: :restrict_with_exception
    has_many :providers, through: :provider_links
  end

  module ClassMethods
    def find_linked(provider, external_id)
      # @type self: ActiveRecord::Base::ClassMethods[ActiveRecord::Base, ActiveRecord::Relation, Integer]
      joins(:provider_links).find_by(provider_links: { provider_id: provider.id, external_id: external_id.to_s })
    end
  end

  def provider_ref(provider)
    provider_links.find_by(provider:)&.external_id
  end
end
