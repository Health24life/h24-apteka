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

  # What the template gives a page, as if nothing were set by hand. A filter takes its own name for a text its template
  # leaves empty, so its page always has a heading.
  def self.generated(page)
    values = values_for(page.record)
    texts = generate(template_for(page), values, page.page_number.to_i)
    title, description, h1 = page.record.is_a?(Seo::Filter) ? named(texts, values['name'].to_s) : texts
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
    when Catalog::Goods then goods_values(record)
    when Catalog::Category, Seo::StaticPage then { 'name' => record.name_uk }
    when Seo::Filter then { 'name' => record.name_uk, 'category' => record.category&.name_uk }
    else {}
    end
  end

  def self.goods_values(goods)
    { 'name' => goods.name_uk, 'inn' => goods.mnn, 'producer' => goods.goods_group.producer&.name,
      'form' => goods.form&.name_uk.presence || goods.release_form, 'dosage' => goods.dosage }
  end

  def self.named(texts, name)
    title, description, h1 = texts
    [ title.presence || Seo::Templates::Truncate.call(name, TITLE_LIMIT),
      description.presence || Seo::Templates::Truncate.call(name, DESCRIPTION_LIMIT), h1.presence || name ]
  end

  def self.limited(text, values, limit, suffix)
    Seo::Templates::Truncate.call(Seo::Templates::Render.call(text, values), limit - suffix.length) + suffix
  end

  private_class_method :by_hand, :generate, :goods_values, :named, :limited

  def initialize(title:, description:, h1:, seo_text:)
    @title = title
    @description = description
    @h1 = h1
    @seo_text = seo_text
  end
end
