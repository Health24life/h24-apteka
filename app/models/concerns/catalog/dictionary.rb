# frozen_string_literal: true

module Catalog::Dictionary
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ActiveRecord::Base) & Translatable::ClassMethods
    include Catalog::ProviderLinked
    include Translatable

    translatable :name

    validates :name_uk, presence: true
  end
end
