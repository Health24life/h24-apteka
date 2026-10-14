# frozen_string_literal: true

# The general template of each page type, so no page is left without texts. The wording lives in the Ukrainian locale
# under `seo.templates.defaults`; a template already there is left as it is.
class Seo::Templates::Defaults
  # Returns the page types it added a template for.
  def self.call
    Seo::Template.page_types.values.filter_map do |page_type|
      next if Seo::Template.exists?(page_type:, category_id: nil, is_recipe: nil)

      texts = Seo::Template::TEXTS.to_h do |text|
        [ :"#{text}_uk", I18n.t(text, scope: [ :seo, :templates, :defaults, page_type ], locale: :uk) ]
      end
      Seo::Template.create!(page_type:, **texts)
      page_type
    end
  end
end
