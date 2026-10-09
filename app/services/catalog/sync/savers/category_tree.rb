# frozen_string_literal: true

# Saves the category tree. A branch whose parent could not be saved waits for the next run.
class Catalog::Sync::Savers::CategoryTree
  def initialize(linker, tracker)
    @linker = linker
    @tracker = tracker
  end

  def call(nodes, parent = nil)
    nodes.each do |node|
      category = save(node, parent)
      call(node.children, category) if category
    end
  end

  private

  def save(node, parent)
    @tracker.guard('Catalog::Category', node.external_id, node) do
      category = @linker.sync(Catalog::Category, node.external_id, { name_uk: node.name, parent: })
      @tracker.processed!
      category
    end
  end
end
