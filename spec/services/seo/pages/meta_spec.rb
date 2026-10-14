# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Pages::Meta do
  let(:producer) { create(:catalog_producer, name: 'Reckitt') }
  let(:goods) do
    create(:catalog_goods, name_uk: 'Нурофен', dosage: '200 мг', mnn: 'Ібупрофен',
                           goods_group: create(:catalog_goods_group, producer:))
  end

  before do
    create(:seo_template, title: '{name} {dosage} — інструкція, {producer}', description: '{name} ({inn}): склад',
                          h1: '{name} {dosage}')
    create(:seo_template, page_type: 'category', title: '{name}', description: 'Розділ {name}', h1: '{name}')
  end

  def page(record, type: :goods, page_number: nil)
    Seo::Pages::Resolve::Page.new(type:, record:, order_number: nil, page_number:, filters: {})
  end

  it 'builds the texts of a product page from its template', :aggregate_failures do
    meta = described_class.call(page(goods))

    expect(meta).to have_attributes(title: 'Нурофен 200 мг — інструкція, Reckitt', h1: 'Нурофен 200 мг',
                                    description: 'Нурофен (Ібупрофен): склад', seo_text: nil)
  end

  it 'takes a field set by hand over the template', :aggregate_failures do
    create(:seo_override, target: goods, title_uk: 'Нурофен: інструкція', seo_text_uk: 'Текст')

    meta = described_class.call(page(goods))

    expect(meta).to have_attributes(title: 'Нурофен: інструкція', seo_text: 'Текст',
                                    description: 'Нурофен (Ібупрофен): склад')
  end

  it 'keeps the generated title and description within their limits', :aggregate_failures do
    goods.update!(name_uk: "Нурофен #{'дуже довга назва ' * 10}")

    meta = described_class.call(page(goods))

    expect(meta.title.length).to be <= described_class::TITLE_LIMIT
    expect(meta.title).to end_with('…')
  end

  it 'says the number of a later page of a list', :aggregate_failures do
    category = create(:catalog_category, name_uk: 'Знеболювальні')

    second = described_class.call(page(category, type: :category, page_number: 2))

    expect(second).to have_attributes(title: 'Знеболювальні — сторінка 2',
                                      description: 'Розділ Знеболювальні — сторінка 2')
    expect(described_class.call(page(category, type: :category)).title).to eq('Знеболювальні')
  end

  it 'never puts a price or the stock into the texts' do
    meta = described_class.call(page(goods))

    expect([ meta.title, meta.description, meta.h1, meta.seo_text ].compact.join(' ')).not_to match(/ціна|грн|наявн/i)
  end

  describe 'a static page' do
    let(:static_page) { create(:seo_static_page, :published, name_uk: 'Умови сервісу') }

    before do
      create(:seo_template, page_type: 'static', title: '{name} — Аптека Health24', description: '{name}: правила',
                            h1: '{name}')
    end

    it 'fills the static page template with the name of the page', :aggregate_failures do
      meta = described_class.call(page(static_page, type: :static))

      expect(meta.title).to eq('Умови сервісу — Аптека Health24')
      expect(meta.h1).to eq('Умови сервісу')
    end

    it 'takes the meta tags of the home page set by hand' do
      create(:seo_template, page_type: 'home', title: 'Аптека', description: 'Аптека', h1: 'Аптека')
      home = create(:seo_static_page, :home)
      create(:seo_override, target: home, title_uk: 'Аптека Health24 — бронювання ліків')

      expect(described_class.call(page(home, type: :home)).title).to eq('Аптека Health24 — бронювання ліків')
    end
  end

  describe 'a filter page' do
    let(:vitamins) { create(:catalog_category, name_uk: 'Вітаміни') }
    let(:filter) { create(:seo_filter, :published, name_uk: 'Вітаміни для дітей', category: vitamins) }

    def filter_template(**texts)
      create(:seo_template, page_type: 'filter', title: '{name} ({category}) — Аптека Health24',
                            description: '{name}: добірка', h1: '{name}', **texts)
    end

    it 'fills the filter template with the names of the filter and of its category' do
      filter_template

      expect(described_class.call(page(filter, type: :filter)).title)
        .to eq('Вітаміни для дітей (Вітаміни) — Аптека Health24')
    end

    it 'leaves the category out for a filter without one' do
      filter_template
      filter.update!(category: nil)

      expect(described_class.call(page(filter, type: :filter)).title).to eq('Вітаміни для дітей — Аптека Health24')
    end

    it 'takes the name of the filter for a text its template leaves empty', :aggregate_failures do
      filter_template(h1: '{category}', description: '{category}')
      filter.update!(category: nil)
      meta = described_class.call(page(filter, type: :filter))

      expect(meta.h1).to eq('Вітаміни для дітей')
      expect(meta.description).to eq('Вітаміни для дітей')
    end

    it 'takes the heading and the SEO text set by hand', :aggregate_failures do
      filter_template
      create(:seo_override, target: filter, h1_uk: 'Вітаміни для дітей від 3 років', seo_text_uk: '<p>Добірка</p>')
      meta = described_class.call(page(filter, type: :filter))

      expect(meta).to have_attributes(h1: 'Вітаміни для дітей від 3 років', seo_text: '<p>Добірка</p>',
                                      title: 'Вітаміни для дітей (Вітаміни) — Аптека Health24')
    end
  end
end
