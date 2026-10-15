# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Filters::Preview do
  let(:syrup) { create(:catalog_goods_form, name_uk: 'Сироп') }

  def filter(**attributes) = build(:seo_filter, params: { 'form_id' => [ syrup.id ] }, **attributes)

  it 'counts the goods of a filter not saved yet and lists them by name' do
    ambroxol = create(:catalog_goods, form: syrup, name_uk: 'Амброксол')
    bronchipret = create(:catalog_goods, form: syrup, name_uk: 'Бронхіпрет')
    create(:catalog_goods, form: create(:catalog_goods_form))

    expect(described_class.call(filter)).to have_attributes(count: 2, goods: [ ambroxol, bronchipret ])
  end

  it 'lists only the first goods but counts them all', :aggregate_failures do
    stub_const("#{described_class}::LIMIT", 2)
    %w[Вугілля Амброксол Бронхіпрет].each { create(:catalog_goods, form: syrup, name_uk: it) }

    preview = described_class.call(filter)

    expect(preview.count).to eq(3)
    expect(preview.goods.map(&:name_uk)).to eq(%w[Амброксол Бронхіпрет])
  end

  it 'gives nothing when no goods match' do
    expect(described_class.call(filter)).to have_attributes(count: 0, goods: [])
  end

  it 'keeps to the prescription scope of the filter', :aggregate_failures do
    create(:catalog_goods, form: syrup, is_recipe: true)

    expect(described_class.call(filter).count).to eq(0)
    expect(described_class.call(filter(recipe_scope: 'any')).count).to eq(1)
  end
end
