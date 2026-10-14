# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Templates::Preview do
  let(:painkillers) { create(:catalog_category, name_uk: 'Знеболювальні') }
  let(:goods) do
    create(:catalog_goods, name_uk: 'Нурофен', dosage: '200 мг', is_recipe: false).tap do |sku|
      create(:catalog_goods_group_category, goods_group: sku.goods_group, category: painkillers, is_primary: true)
    end
  end

  def template(**) = build(:seo_template, **)

  it 'fills the texts of a product template on a real SKU without saving it', :aggregate_failures do
    preview = described_class.call(template: template(title: '{name} {dosage} — інструкція'), record: goods)

    expect(preview.title).to have_attributes(value: 'Нурофен 200 мг — інструкція', cut?: false)
    expect(Seo::Template.count).to eq(0)
  end

  it 'shows a title that is too long as search engines would see it cut', :aggregate_failures do
    preview = described_class.call(template: template(title: "{name} #{'дуже ' * 20}довгий"), record: goods)

    expect(preview.title.length).to be > Seo::Pages::Meta::TITLE_LIMIT
    expect(preview.title.value).to end_with('…').and(satisfy { it.length <= Seo::Pages::Meta::TITLE_LIMIT })
    expect(preview).to be_cut
  end

  it 'fills a category template' do
    preview = described_class.call(template: template(page_type: 'category', title: '{name} — каталог'),
                                   record: painkillers)

    expect(preview.title.value).to eq('Знеболювальні — каталог')
  end

  it 'fills a static page template' do
    preview = described_class.call(template: template(page_type: 'static', title: '{name} — Аптека'),
                                   record: create(:seo_static_page, name_uk: 'Умови'))

    expect(preview.title.value).to eq('Умови — Аптека')
  end

  it 'offers only the SKUs of the branch and prescription kind of the template', :aggregate_failures do
    elsewhere = create(:catalog_goods)
    narrowed = template(category: painkillers, is_recipe: false)

    expect(described_class.records(narrowed)).to contain_exactly(goods)
    expect(described_class.applies_to?(narrowed, elsewhere)).to be(false)
    expect(described_class.records(template(category: painkillers, is_recipe: true))).to be_empty
  end

  it 'offers the categories of the branch, the category itself included' do
    child = create(:catalog_category, parent: painkillers)
    create(:catalog_category)

    expect(described_class.records(template(page_type: 'category', category: painkillers)))
      .to contain_exactly(painkillers, child)
  end
end
