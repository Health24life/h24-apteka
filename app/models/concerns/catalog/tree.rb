# frozen_string_literal: true

module Catalog::Tree
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ActiveRecord::Base)
    belongs_to :parent, class_name: name, optional: true, inverse_of: :children

    has_many :children, class_name: name, foreign_key: :parent_id, inverse_of: :parent,
                        dependent: :restrict_with_exception

    validate :parent_is_not_self

    scope :roots, lambda {
      # @type self: ActiveRecord::Relation
      where(parent_id: nil)
    }
  end

  private

  def parent_is_not_self
    errors.add(:parent, :invalid) if parent_id.present? && parent_id == id
  end
end
