# frozen_string_literal: true

module Mixins
  # Default Ransack allowlist for every ApplicationRecord. Ransack 4 requires an
  # explicit allowlist of searchable attributes/associations; instead of repeating
  # it in every model, expose the full built-in list here. Models that must hide a
  # column (secrets like session_key / encrypted_password) override
  # `ransackable_attributes` themselves — a singleton method on the model wins over
  # this extended module.
  module RansackableAttrs
    def ransackable_attributes(_auth_object = nil)
      authorizable_ransackable_attributes
    end

    def ransackable_associations(_auth_object = nil)
      authorizable_ransackable_associations
    end
  end
end
