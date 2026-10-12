# frozen_string_literal: true

# What search engines may do with a page that is there. A cart or an order is private; a filtered list or a category
# with nothing to show only leads on to products; the rest is indexed.
class Seo::Pages::Robots
  INDEX = 'index, follow'
  FOLLOW_ONLY = 'noindex, follow'
  NONE = 'noindex, nofollow'

  def self.call(page)
    case page.type
    when :cart, :order then NONE
    when :category then page.filters.any? || !category_shown?(page.record) ? FOLLOW_ONLY : INDEX
    else INDEX
    end
  end

  def self.category_shown?(category) = category.is_a?(Catalog::Category) && category.shown_goods?

  private_class_method :category_shown?
end
