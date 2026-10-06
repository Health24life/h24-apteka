# frozen_string_literal: true

# The database refuses only a node that is its own parent; a longer cycle is caught here. The visited set stops the
# walk at a cycle already written past the model.
class TreeParentValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :invalid) if ancestors_include?(value, record)
  end

  private

  def ancestors_include?(node, record)
    visited = Set[]
    while node && visited.add?(node)
      return true if node == record

      node = node.parent
    end
    false
  end
end
