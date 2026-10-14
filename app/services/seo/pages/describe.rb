# frozen_string_literal: true

# Everything the front needs to render the head of a page, its breadcrumbs and the text of a static page, built from the
# Health24 database only:
# the partner is never asked, and prices or stock never appear. A guest and a signed-in user get the same answer.
class Seo::Pages::Describe
  attr_reader :status, :location, :title, :description, :h1, :robots, :breadcrumbs, :seo_text, :content

  def self.call(path)
    result = Seo::Pages::Resolve.call(path)
    page = result.page
    return elsewhere(result) unless page && result.status == 200

    meta = Seo::Pages::Meta.call(page)
    new(status: result.status, location: nil, title: meta.title, description: meta.description, h1: meta.h1,
        robots: Seo::Pages::Robots.call(page), breadcrumbs: Seo::Pages::Breadcrumbs.call(page), seo_text: meta.seo_text,
        content: content_of(page.record))
  end

  # The front draws the home page itself; only the other static pages carry a text of their own.
  def self.content_of(record)
    record.content.presence if record.is_a?(Seo::StaticPage) && !record.home?
  end

  # A redirect or a page that is not there: only the status, and the new path for a redirect.
  def self.elsewhere(result)
    robots = result.location ? nil : Seo::Pages::Robots::NONE
    new(status: result.status, location: result.location, title: nil, description: nil, h1: nil, robots:,
        breadcrumbs: [], seo_text: nil, content: nil)
  end

  private_class_method :content_of, :elsewhere

  # rubocop:disable-next Metrics/ParameterLists -- every field of the answer, each given by name.
  def initialize(status:, location:, title:, description:, h1:, robots:, breadcrumbs:, seo_text:, content:)
    @status = status
    @location = location
    @title = title
    @description = description
    @h1 = h1
    @robots = robots
    @breadcrumbs = breadcrumbs
    @seo_text = seo_text
    @content = content
  end
end
