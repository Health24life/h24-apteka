# frozen_string_literal: true

# The SKUs a filter selects: shown on the storefront, matching every parameter of the filter by any of its values, a
# category taking in its subcategories, within the filter's prescription scope. The selection is never stored; the
# page of goods of the catalog search takes the same scope.
class Seo::Filters::Goods
  def self.call(filter)
    scope = Seo::Filter::PARAMS.each_key.reduce(Catalog::Goods.shown) do |selected, key|
      ids = filter.params[key]
      ids.present? ? narrowed(selected, key, Array(ids)) : selected
    end
    prescribed(scope, filter.recipe_scope.to_s)
  end

  def self.any?(filter) = call(filter).exists?

  # A category goes by every link of a group, not only its primary one, as the storefront of the category does.
  def self.narrowed(scope, key, ids)
    case key
    when 'category_id' then scope.where(goods_group_id: in_branches(ids))
    when 'producer_id' then scope.where(goods_group: { producer_id: ids })
    else scope.where(key => ids)
    end
  end

  def self.in_branches(category_ids)
    Catalog::Goods::Group::Category.where(<<~SQL.squish, category_ids).select(:goods_group_id)
      category_id IN (SELECT descendant_id FROM catalog_category_hierarchies WHERE ancestor_id IN (?))
    SQL
  end

  def self.prescribed(scope, recipe_scope)
    case recipe_scope
    when 'otc' then scope.where(is_recipe: false)
    when 'rx' then scope.where(is_recipe: true)
    else scope
    end
  end

  private_class_method :narrowed, :in_branches, :prescribed
end
