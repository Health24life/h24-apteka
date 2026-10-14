# frozen_string_literal: true

# What a template, saved or not, gives on a real page: each text as the SEO endpoint would return it, its full length
# and whether search engines would see it cut. The records it can be tried on are the ones it would apply to.
class Seo::Templates::Preview
  class Text < Data.define(:value, :length, :limit)
    def cut? = !limit.nil? && length > limit.to_i
  end

  class Result < Data.define(:title, :description, :h1)
    def cut? = title.cut? || description.cut?
  end

  MODELS = { 'goods' => Catalog::Goods, 'category' => Catalog::Category, 'static' => Seo::StaticPage }.freeze

  def self.call(template:, record:)
    values = Seo::Pages::Meta.values_for(record)
    Result.new(title: text(template.title, values, Seo::Pages::Meta::TITLE_LIMIT),
               description: text(template.description, values, Seo::Pages::Meta::DESCRIPTION_LIMIT),
               h1: text(template.h1, values, nil))
  end

  # The records of the template's page type within its branch and of its prescription kind.
  def self.records(template)
    branch = template.category&.self_and_descendants
    case template.page_type.to_s
    when 'goods' then goods(template, branch)
    when 'category' then branch || Catalog::Category.all
    when 'static' then Seo::StaticPage.pages
    else Seo::StaticPage.none
    end
  end

  # The records for a template of the page type whose branch and prescription kind come as request parameters.
  def self.options(page_type, params)
    recipe = ActiveModel::Type::Boolean.new.cast(params[:is_recipe].presence)
    records(Seo::Template.new(page_type:, category_id: params[:category_id].presence, is_recipe: recipe))
  end

  def self.applies_to?(template, record) = !record.nil? && records(template).exists?(id: record.id)

  def self.goods(template, branch)
    scope = Catalog::Goods.all
    scope = scope.where(is_recipe: template.is_recipe) unless template.is_recipe.nil?
    return scope unless branch

    groups = Catalog::Goods::Group::Category.where(is_primary: true, category: branch).select(:goods_group_id)
    scope.where(goods_group_id: groups)
  end

  def self.text(text, values, limit)
    full = Seo::Templates::Render.call(text.to_s, values)
    Text.new(value: limit ? Seo::Templates::Truncate.call(full, limit) : full, length: full.length, limit:)
  end

  private_class_method :goods, :text
end
