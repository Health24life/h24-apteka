# frozen_string_literal: true

module Catalog::Dictionary
  extend ActiveSupport::Concern

  included do
    include Catalog::ProviderLinked
    include Translatable

    translatable :name

    validates :name_uk, presence: true
  end
end
