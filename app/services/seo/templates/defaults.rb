# frozen_string_literal: true

# The general template of each page type, so no page is left without texts. The wording is a working draft until the
# product owner and the lawyer agree on it; a template already there is left as it is.
class Seo::Templates::Defaults
  TEXTS = {
    'home' => [ 'Аптека Health24 — пошук ліків і бронювання в аптеках',
                'Знайдіть лікарські засоби, перегляньте інструкції та забронюйте їх в аптеці поруч без передоплати.',
                'Аптека Health24' ],
    'category' => [ '{name} — каталог Аптеки Health24',
                    '{name}: лікарські засоби та товари для здоровʼя з інструкціями із застосування.',
                    '{name}' ],
    'goods' => [ '{name} {dosage} — інструкція із застосування',
                 '{name} {dosage} ({inn}), {producer}: склад, показання, протипоказання та спосіб застосування.',
                 '{name} {dosage}' ],
    'cart' => [ 'Кошик — Аптека Health24', 'Товари, обрані для бронювання в аптеці.', 'Кошик' ],
    'order' => [ 'Замовлення — Аптека Health24', 'Бронювання товарів в аптеці.', 'Замовлення' ]
  }.freeze

  # Returns the page types it added a template for.
  def self.call
    TEXTS.filter_map do |page_type, (title, description, h1)|
      next if Seo::Template.exists?(page_type:, category_id: nil, is_recipe: nil)

      Seo::Template.create!(page_type:, title:, description:, h1:)
      page_type
    end
  end
end
