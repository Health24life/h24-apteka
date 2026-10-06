# frozen_string_literal: true

# Saves a category with the depth taken from its parent and, when the category moved, shifts the branch below it.
class Catalog::Categories::Saver
  def self.call(category)
    moved = category.persisted? && category.will_save_change_to_parent_id?
    parent = category.parent
    category.depth = parent ? parent.depth + 1 : 0
    category.save!
    Catalog::Trees::DescendantsDepthUpdater.call(category) if moved
    category
  end
end
