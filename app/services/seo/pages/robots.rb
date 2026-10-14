# frozen_string_literal: true

# What search engines may do with a page that is there. A cart or an order is private; a filtered list, or a category
# or a filter with nothing to show, only leads on to products; the rest is indexed. An operator may force indexing on
# or off for the page of a record; a filtered list of a category stays out of the index whatever its category says.
class Seo::Pages::Robots
  INDEX = 'index, follow'
  FOLLOW_ONLY = 'noindex, follow'
  NONE = 'noindex, nofollow'

  FORCED = { 'index' => INDEX, 'noindex' => FOLLOW_ONLY }.freeze

  def self.call(page)
    case page.type
    when :cart, :order then NONE
    when :category then category(page)
    when :filter then forced(page) || listing(filter_stocked?(page.record))
    else forced(page) || INDEX
    end
  end

  def self.category(page)
    return FOLLOW_ONLY if page.filters.any?

    forced(page) || listing(category_shown?(page.record))
  end

  # A page that lists goods is indexed while it has some to show.
  def self.listing(stocked) = stocked ? INDEX : FOLLOW_ONLY

  def self.forced(page) = FORCED[page.record&.seo_override&.robots.to_s]

  def self.category_shown?(category) = category.is_a?(Catalog::Category) && category.shown_goods?

  def self.filter_stocked?(filter) = filter.is_a?(Seo::Filter) && Seo::Filters::Goods.any?(filter)

  private_class_method :category, :listing, :forced, :category_shown?, :filter_stocked?
end
