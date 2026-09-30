# frozen_string_literal: true

module Translatable
  extend ActiveSupport::Concern

  # Mixed into the generated translation class: the catalog is stored in the configured locales only.
  module LocaleRestriction
    extend ActiveSupport::Concern

    included do
      # @type self: singleton(ActiveRecord::Base)
      validate :locale_is_a_catalog_locale
    end

    private

    def locale_is_a_catalog_locale
      return if Rails.configuration.x.catalog_locales.map(&:to_s).include?(self[:locale].to_s)

      errors.add(:locale, :inclusion)
    end
  end

  module ClassMethods
    # Called once per model with every translated attribute: each globalize_accessors call overwrites the previous list.
    def translatable(*attributes, **)
      # @type self: singleton(ActiveRecord::Base)
      translates(*attributes, **)
      globalize_accessors(attributes:, locales: Rails.configuration.x.catalog_locales)
      # @type var model: untyped
      model = self
      model.translation_class.include(LocaleRestriction)
    end
  end
end
