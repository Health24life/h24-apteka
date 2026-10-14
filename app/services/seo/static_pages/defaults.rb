# frozen_string_literal: true

# The home page's row, the target of its meta tags. The other static pages are written by editors.
class Seo::StaticPages::Defaults
  # Returns whether it added the row.
  def self.call
    return false if Seo::StaticPage.home

    Seo::StaticPage.create!(key: Seo::StaticPage::HOME,
                            name_uk: I18n.t(:home, scope: 'seo.pages.breadcrumbs', locale: :uk))
    true
  end
end
