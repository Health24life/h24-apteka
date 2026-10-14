# frozen_string_literal: true

# The SEO data with a history by several admins: templates narrowed by branches and prescription, overrides of pages,
# static pages, slug changes with their automatic redirects and redirects editors set by hand.
module DevSamples::Seo
  PAGES = [
    [ 'yak-tse-pratsiuie', 'Як це працює', true ], [ 'umovy-servisu', 'Умови сервісу', true ],
    [ 'pro-servis', 'Про сервіс', true ], [ 'dostavka-i-oplata', 'Отримання й оплата', true ],
    [ 'pytannia-i-vidpovidi', 'Питання й відповіді', true ], [ 'kontakty', 'Контакти', true ],
    [ 'aktsii', 'Акції', false ], [ 'partneram', 'Партнерам', false ]
  ].freeze
  CONTENT = '<h2>%<name>s</h2><p>Health24 допомагає знайти ліки й забронювати їх в аптеці ' \
            '<strong>без передоплати</strong>.</p><ol><li>Знайдіть ліки.</li><li>Оберіть аптеку.</li>' \
            '<li>Заберіть замовлення.</li></ol>' \
            '<blockquote>Оплата — в аптеці.</blockquote><p>Дивіться <a href="/katalog/liky">каталог</a>.</p>'

  module_function

  def call(admins)
    Seo::Templates::Defaults.call
    Seo::StaticPages::Defaults.call
    # Each admin writes a part of the templates and overrides, so the history has several authors.
    admins.each_with_index { |admin, part| DevSamples.as(admin) { [ templates(part), overrides(part) ] } }
    DevSamples.as(admins.first) { pages }
    DevSamples.as(admins.second) { slugs }
    DevSamples.as(admins.last) { redirects }
  end

  def templates(part)
    Catalog::Category.where(parent_id: nil).or(Catalog::Category.where.not(parent_id: nil)).order(:id)
                     .each_slice(3).to_a[part].to_a.each do |category|
      template('category', category, nil, '{name} — каталог Аптеки Health24')
      template('goods', category, nil, "{name} {dosage} — #{category.name_uk.downcase}, інструкція")
      template('goods', category, true, '{name} {dosage} — рецептурний препарат, інструкція') if part.zero?
    end
  end

  def template(page_type, category, is_recipe, title)
    Seo::Template.find_or_create_by!(page_type:, category:, is_recipe:) do |template|
      template.assign_attributes(title:, description: "#{title}: склад, показання та спосіб застосування.",
                                 h1: '{name}')
    end
  end

  def overrides(part)
    Catalog::Goods.order(:id).offset(part * 5).limit(5).each do |sku|
      override(sku, title_uk: "#{sku.name_uk}: інструкція із застосування",
                    seo_text_uk: "<p>#{sku.name_uk} — <strong>#{sku.mnn || 'засіб'}</strong>.</p>")
    end
    Catalog::Category.order(:id).offset(part * 3).limit(3).each do |category|
      override(category, description_uk: "#{category.name_uk} з інструкціями та аптеками поруч.",
                         robots: part == 2 ? 'noindex' : 'auto')
    end
  end

  def override(record, **fields)
    (record.seo_override || record.build_seo_override).update!(fields)
  end

  def pages
    PAGES.each do |slug, name, published|
      Seo::StaticPage.find_or_create_by!(slug:) do |page|
        page.assign_attributes(name_uk: name, published:, content_uk: format(CONTENT, name:))
      end
    end
    override(Seo::StaticPage.home, title_uk: 'Аптека Health24 — пошук ліків і бронювання без передоплати')
  end

  # Changes the slugs of ten SKUs, which leaves their automatic redirects.
  def slugs
    Catalog::Goods.order(:id).limit(10).each do |sku|
      sku.update!(slug: "#{sku.slug}-new") unless sku.slug.end_with?('-new')
    end
  end

  # Redirects from the slugs of withdrawn SKUs to their category, and from old addresses to pages that are there.
  def redirects
    withdrawn.find_each do |sku|
      category = sku.goods_group.primary_category or next
      manual("/tovar/#{sku.slug}", "/katalog/#{category.slug}")
    end
    targets = (Catalog::Category.order(:id).pluck(:slug).map { "/katalog/#{it}" } + %w[/ /yak-tse-pratsiuie]).cycle
    30.times { |number| manual("/tovar/stara-adresa-#{number + 1}", targets.next) }
  end

  def withdrawn
    groups = Catalog::Goods::Group.where(withdrawn: true)
    Catalog::Goods.where(withdrawn: true).or(Catalog::Goods.where(goods_group: groups))
                  .includes(goods_group: :primary_category)
  end

  def manual(source, target)
    return if Seo::Redirect.exists?(slug: source.split('/').last)

    result = Seo::Redirects::Manual.call(source:, target:)
    Rails.logger.warn("dev:samples: redirect #{source} → #{target}: #{result.errors}") unless result.ok?
  end
end
