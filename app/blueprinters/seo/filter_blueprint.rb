# frozen_string_literal: true

class Seo::FilterBlueprint < Blueprinter::Base
  identifier :id

  view :list do
    field :name_uk, name: :name
    field :slug
    field(:path) { |filter| Seo::Pages::Path.new.filter(filter.slug) }
  end

  view :card do
    include_view :list
    fields :sort_order, :recipe_scope, :params

    field :category do |filter|
      category = filter.category
      category && { id: category.id, name: category.name_uk, path: Seo::Pages::Path.new.category(category.slug) }
    end

    field(:applied_params) { |filter| Seo::Filters::AppliedParams.call(filter).map(&:to_h) }
  end
end
