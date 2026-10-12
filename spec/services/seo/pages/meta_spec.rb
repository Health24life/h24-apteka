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
    create(:seo_page_setting, settable: goods, title: 'Нурофен: інструкція', seo_text: 'Текст')

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

    expect(meta.to_h.values.compact.join(' ')).not_to match(/ціна|грн|наявн/i)
  end
end
