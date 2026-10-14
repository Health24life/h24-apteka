# frozen_string_literal: true

# Title, description, H1 and SEO text of a page. A field an operator set by hand wins; the rest come from the narrowest
# template, filled from the page's record. Generated texts are cut to the length search engines show, and a later page
# of a list says its number so it does not repeat the first one.
class Seo::Pages::Meta
  TITLE_LIMIT = 70
  DESCRIPTION_LIMIT = 160

  attr_reader :title, :description, :h1, :seo_text

  def self.call(page)
    override = page.record&.seo_override
    generated = generated(page)
    new(title: by_hand(override, :title) || generated.title,
        description: by_hand(override, :description) || generated.description,
        h1: by_hand(override, :h1) || generated.h1, seo_text: override&.seo_text.presence)
  end

  # What the template gives a page, as if nothing were set by hand.
  def self.generated(page)
    title, description, h1 = generate(template_for(page), values_for(page.record), page.page_number.to_i)
    new(title:, description:, h1:, seo_text: nil)
  end

  # A field an operator filled in; an empty one leaves the template's.
  def self.by_hand(override, field) = override&.public_send(field).presence

  def self.generate(template, values, page_number)
    suffix = page_number > 1 ? " — сторінка #{page_number}" : ''
    [ limited(template.title.to_s, values, TITLE_LIMIT, suffix),
      limited(template.description.to_s, values, DESCRIPTION_LIMIT, suffix),
      Seo::Templates::Render.call(template.h1.to_s, values) ]
  end

  # The narrowest template that fits a page.
  def self.template_for(page)
    case (record = page.record)
    when Catalog::Goods
      Seo::Templates::Pick.call(page_type: 'goods', category: record.goods_group.primary_category,
                                recipe: record.is_recipe)
    when Catalog::Category then Seo::Templates::Pick.call(page_type: 'category', category: record)
    else Seo::Templates::Pick.call(page_type: page.type.to_s)
    end
  end

  def self.values_for(record)
    case record
    when Catalog::Goods
      { 'name' => record.name_uk, 'inn' => record.mnn, 'producer' => record.goods_group.producer&.name,
        'form' => record.form&.name_uk.presence || record.release_form, 'dosage' => record.dosage }
    when Catalog::Category, Seo::StaticPage then { 'name' => record.name_uk }
    else {}
    end
  end

  def self.limited(text, values, limit, suffix)
    Seo::Templates::Truncate.call(Seo::Templates::Render.call(text, values), limit - suffix.length) + suffix
  end

  private_class_method :by_hand, :generate, :limited

  def initialize(title:, description:, h1:, seo_text:)
    @title = title
    @description = description
    @h1 = h1
    @seo_text = seo_text
  end
end
