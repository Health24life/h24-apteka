# frozen_string_literal: true

# Rewrites the depth of every category below the given one in a single statement, so a descendant that fails
# validation cannot block the move of its branch. The path stops the walk at a cycle written past the model.
class Catalog::Trees::DescendantsDepthUpdater
  STATEMENT = <<~SQL.squish
    WITH RECURSIVE descendants (id, depth, path) AS (
      SELECT id, :depth + 1, ARRAY[:id, id] FROM catalog_categories WHERE parent_id = :id
      UNION ALL
      SELECT child.id, descendants.depth + 1, descendants.path || child.id
      FROM catalog_categories child JOIN descendants ON child.parent_id = descendants.id
      WHERE child.id <> ALL (descendants.path)
    )
    UPDATE catalog_categories SET depth = descendants.depth FROM descendants
    WHERE catalog_categories.id = descendants.id
  SQL

  def self.call(category)
    sql = Catalog::Category.sanitize_sql_array([ STATEMENT, { id: category.id, depth: category.depth } ])
    updated = Catalog::Category.connection.exec_update(sql)
    category.children.reset
    updated
  end
end
