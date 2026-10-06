# frozen_string_literal: true

module Catalog::Tree
  extend ActiveSupport::Concern

  included do
    belongs_to :parent, class_name: name, optional: true, inverse_of: :children

    has_many :children, class_name: name, foreign_key: :parent_id, inverse_of: :parent,
                        dependent: :restrict_with_exception

    validates :parent, tree_parent: true, if: :will_save_change_to_parent_id?

    scope :roots, -> { where(parent_id: nil) }
  end
end
