# frozen_string_literal: true

module Translatable
  extend ActiveSupport::Concern

  module ClassMethods
    # Called once per model with every translated attribute: each globalize_accessors call overwrites the previous list.
    def translatable(*attributes, **)
      # @type self: singleton(ActiveRecord::Base)
      translates(*attributes, **)
      globalize_accessors(attributes:, locales: Rails.configuration.x.catalog_locales)
    end
  end
end
