# frozen_string_literal: true

# Chooses the narrowest template that fits a page. The branch decides first: a template of the nearest category of the
# page's branch wins over one of a farther ancestor, and any branch wins over none. Within the same branch a template
# for the product's prescription kind wins over one that does not narrow it down.
class Seo::Templates::Pick
  class Missing < StandardError; end

  def self.call(page_type:, category: nil, recipe: nil)
    scope = Seo::Template.where(page_type:)
    scope = page_type.to_s == 'goods' ? scope.where(is_recipe: [ nil, recipe ]) : scope.where(is_recipe: nil)
    branch(scope, category).first or raise Missing, "No general SEO template for #{page_type} pages"
  end

  def self.branch(scope, category)
    return scope.where(category_id: nil) unless category

    scope.joins(ancestry_of(category)).where(general_or_in_branch).order(narrowest_first)
  end

  # Joins each template of a category to the ancestry of the page's category, so a template of an ancestor gets the
  # distance to it and a template of another branch gets nothing.
  def self.ancestry_of(category)
    Arel.sql(ActiveRecord::Base.sanitize_sql_array([ <<~SQL.squish, category.id ]))
      LEFT JOIN catalog_category_hierarchies hierarchy
        ON hierarchy.ancestor_id = seo_templates.category_id AND hierarchy.descendant_id = ?
    SQL
  end

  def self.general_or_in_branch = 'seo_templates.category_id IS NULL OR hierarchy.ancestor_id IS NOT NULL'

  # The nearest category first, then a template for the prescription kind before one that does not narrow it down.
  def self.narrowest_first = Arel.sql('hierarchy.generations ASC NULLS LAST, seo_templates.is_recipe ASC NULLS LAST')

  private_class_method :branch, :ancestry_of, :general_or_in_branch, :narrowest_first
end
