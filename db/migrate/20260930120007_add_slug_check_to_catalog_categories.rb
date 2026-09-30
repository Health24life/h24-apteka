class AddSlugCheckToCatalogCategories < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :catalog_categories, "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) <= 100",
                         name: 'catalog_categories_slug_check'
  end
end
