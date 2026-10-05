# frozen_string_literal: true

module H24Core::HstoreTranslated
  extend ActiveSupport::Concern

  module ClassMethods
    def hstore_translated(name, column)
      define_method(name) do |locale = I18n.locale|
        translations = self[column] || {}
        I18n.fallbacks[locale].lazy.filter_map { |fallback| translations[fallback.to_s].presence }.first
      end
    end
  end
end
