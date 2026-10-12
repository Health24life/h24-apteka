# frozen_string_literal: true

# Title, description, H1 and SEO text of a page. A field an operator set by hand wins; the rest come from the narrowest
# template, filled from the page's record. Generated texts are cut to the length search engines show, and a later page
# of a list says its number so it does not repeat the first one.
class Seo::Pages::Meta < Data.define(:title, :description, :h1, :seo_text)
  TITLE_LIMIT = 70
  DESCRIPTION_LIMIT = 160

  def self.call(page)
    setting = page.record&.seo_page_setting
    generated = generate(template_for(page), values_for(page.record), page.page_number.to_i)
    new(title: setting&.title || generated[:title], description: setting&.description || generated[:description],
        h1: setting&.h1 || generated[:h1], seo_text: setting&.seo_text)
  end

  def self.generate(template, values, page_number)
    suffix = page_number > 1 ? " — сторінка #{page_number}" : ''
    { title: limited(template.title, values, TITLE_LIMIT, suffix),
      description: limited(template.description, values, DESCRIPTION_LIMIT, suffix),
      h1: Seo::Templates::Render.call(template.h1, values) }
  end

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
    when Catalog::Category then { 'name' => record.name_uk }
    else {}
    end
  end

  def self.limited(text, values, limit, suffix)
    Seo::Templates::Truncate.call(Seo::Templates::Render.call(text, values), limit - suffix.length) + suffix
  end

  private_class_method :generate, :template_for, :values_for, :limited
end
