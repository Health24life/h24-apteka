# frozen_string_literal: true

# What search engines may do with a page that is there. A cart or an order is private; a filtered list or a category
# with nothing to show only leads on to products; the rest is indexed. An operator may force indexing on or off for
# the page of a record; a filtered list of a category stays out of the index whatever its category says.
class Seo::Pages::Robots
  INDEX = 'index, follow'
  FOLLOW_ONLY = 'noindex, follow'
  NONE = 'noindex, nofollow'

  FORCED = { 'index' => INDEX, 'noindex' => FOLLOW_ONLY }.freeze

  def self.call(page)
    case page.type
    when :cart, :order then NONE
    when :category
      return FOLLOW_ONLY if page.filters.any?

      forced(page) || (category_shown?(page.record) ? INDEX : FOLLOW_ONLY)
    else forced(page) || INDEX
    end
  end

  def self.forced(page) = FORCED[page.record&.seo_override&.robots.to_s]

  def self.category_shown?(category) = category.is_a?(Catalog::Category) && category.shown_goods?

  private_class_method :forced, :category_shown?
end
