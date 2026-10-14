# frozen_string_literal: true

# A catalog to page through: a tree of categories and goods groups of several dosages each, some of them withdrawn by
# the provider, prescription only or hidden by an operator, and the instructions of the first SKUs.
module DevSamples::Catalog
  SECTIONS = %w[sklad pokazannia protypokazannia sposib-zastosuvannia-ta-dozy].freeze

  module_function

  def call(provider)
    DevSamples::CatalogData::CATEGORIES.each { |slug, name, parent| category(provider, slug, name, parent) }
    DevSamples::CatalogData::GROUPS.each_with_index { |row, index| group(provider, row, index) }
    instructions
  end

  def category(provider, slug, name, parent)
    record = Catalog::Category.find_or_create_by!(slug:) do |category|
      category.name_uk = name
      category.parent = Catalog::Category.find_by(slug: parent) if parent
    end
    DevSamples.link(provider, record, attrs: { 'name' => name })
  end

  # Tablets and capsules also come in a bigger pack, so the catalog has more SKUs than groups.
  PACKS = { 'Таблетки' => [ nil, '№30' ], 'Капсули' => [ nil, '№30' ] }.freeze

  def group(provider, row, index)
    name, inn, producer, form, categories, dosages, recipe = row
    group = Catalog::Goods::Group.joins(:goods_name).find_by(goods_name: { name: }) ||
            create_group(name, producer, categories)
    group.update!(withdrawn: index % 11 == 10)
    DevSamples.link(provider, group, attrs: { 'name' => name })
    dosages.product(PACKS.fetch(form, [ nil ])).each do |dosage|
      DevSamples::Goods.call(provider, group, inn:, form:, dosage: dosage.compact.join(' '), recipe: recipe || false)
    end
  end

  def create_group(name, producer, categories)
    group = Catalog::Goods::Group.create!(
      name_uk: name, producer: Catalog::Producer.find_by!(name: producer), included_to_offers: true,
      goods_name: Catalog::Goods::Name.find_or_create_by!(name:)
    )
    categories.each_with_index do |slug, position|
      group.goods_group_categories.create!(category: Catalog::Category.find_by!(slug:), is_primary: position.zero?)
    end
    group
  end

  def instructions
    Catalog::Goods.order(:id).limit(30).each do |sku|
      next if sku.instruction_sections.exists?

      SECTIONS.each.with_index(1) do |code, position|
        title = I18n.t(code, scope: 'catalog.goods.instruction_sections', locale: :uk)
        sku.instruction_sections.create!(position:, code:, anchor: code, source_title: title,
                                         body_html_uk: "<p>#{title}: зразок тексту інструкції #{sku.name_uk}.</p>")
      end
    end
  end
end
