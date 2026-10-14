# frozen_string_literal: true

# The trail from the home page to a page, each step with its name and the current path of its page. A product goes
# through the main category of its group and that category's ancestors.
class Seo::Pages::Breadcrumbs
  class Crumb < Data.define(:name, :path); end

  def self.call(page, paths: Seo::Pages::Path.new) = new(paths).call(page)

  def initialize(paths)
    @paths = paths
  end

  def call(page)
    home = crumb(:home, @paths.home)
    case page.type
    when :home then [ home ]
    when :cart then [ home, crumb(:cart, @paths.cart) ]
    when :order then [ home, crumb(:order, @paths.order(page.order_number.to_s)) ]
    else [ home, *records(page.record) ]
    end
  end

  private

  def records(record)
    case record
    when Catalog::Category then branch(record)
    when Catalog::Goods then [ *branch(record.goods_group.primary_category), of(record) ]
    when Seo::StaticPage then [ of(record) ]
    else []
    end
  end

  def branch(category) = category ? category.self_and_ancestors.to_a.reverse.map { of(it) } : []

  def of(record) = Crumb.new(name: record.name_uk.to_s, path: @paths.record(record).to_s)

  def crumb(key, path) = Crumb.new(name: I18n.t(key, scope: 'seo.pages.breadcrumbs', locale: :uk), path:)
end
