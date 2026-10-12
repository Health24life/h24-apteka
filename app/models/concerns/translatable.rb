# frozen_string_literal: true

module Translatable
  extend ActiveSupport::Concern

  EMPTY_DEFAULT = -> { {} }

  included do
    extend Mobility
  end

  module ClassMethods
    def translatable(*attributes, backend: :jsonb, **)
      translates(*attributes, backend:, locale_accessors: Rails.configuration.x.catalog_locales, fallbacks: true, **)
      # Some jsonb columns have no database default, and the jsonb backend cannot write into a nil column.
      attributes.each { attribute it, default: EMPTY_DEFAULT } if backend == :jsonb
      validates(*attributes, catalog_locales: true)
    end
  end
end
