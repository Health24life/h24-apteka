# frozen_string_literal: true

# One step: the provider hands the whole tree in a single answer.
class Catalog::Sync::Importers::Categories
  def self.first_cursor = nil

  def self.call(tracker, client, linker, _cursor)
    Catalog::Sync::Savers::CategoryTree.new(linker, tracker).call(client.category_tree)
    nil
  end

  def self.skip(_tracker, _cursor) = nil
end
