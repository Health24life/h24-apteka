# frozen_string_literal: true

module Catalog::Tree
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ActiveRecord::Base)
    belongs_to :parent, class_name: name, optional: true, inverse_of: :children

    has_many :children, class_name: name, foreign_key: :parent_id, inverse_of: :parent,
                        dependent: :restrict_with_exception

    validate :parent_is_not_self_or_descendant, if: :will_save_change_to_parent_id?

    scope :roots, lambda {
      # @type self: ActiveRecord::Relation
      where(parent_id: nil)
    }
  end

  private

  # The database refuses only a node that is its own parent; a longer cycle is caught here.
  def parent_is_not_self_or_descendant
    visited = Set[]
    node = parent
    while node && visited.add?(node)
      return errors.add(:parent, :invalid) if node == self

      node = node.parent
    end
  end
end
