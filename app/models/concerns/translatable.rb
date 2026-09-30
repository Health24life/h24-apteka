# frozen_string_literal: true

module Translatable
  extend ActiveSupport::Concern

  def self.catalog_locale?(locale) = Rails.configuration.x.catalog_locales.map(&:to_s).include?(locale.to_s)

  # Mixed into the generated translation class: the catalog is stored in the configured locales only.
  module LocaleRestriction
    extend ActiveSupport::Concern

    included do
      # @type self: singleton(ActiveRecord::Base)
      validate :locale_is_a_catalog_locale
    end

    private

    def locale_is_a_catalog_locale
      errors.add(:locale, :inclusion) unless Translatable.catalog_locale?(self[:locale])
    end
  end

  module ClassMethods
    # Called once per model with every translated attribute: each globalize_accessors call overwrites the previous list.
    def translatable(*attributes, **)
      # @type self: singleton(ActiveRecord::Base)
      translates(*attributes, **)
      globalize_accessors(attributes:, locales: Rails.configuration.x.catalog_locales)
      validate :translations_are_in_catalog_locales
      # @type var model: untyped
      model = self
      model.translation_class.include(LocaleRestriction)
    end
  end

  private

  # Globalize saves translation rows after the record itself, so a row refused there would leave the record
  # written without it. Pending translations are checked here, before anything reaches the database.
  def translations_are_in_catalog_locales
    globalize.stash.each do |locale, values|
      next if Translatable.catalog_locale?(locale)

      values.each_key { errors.add(it, :not_a_catalog_locale, language: locale) }
    end
  end
end
