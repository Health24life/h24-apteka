# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::PageSetting do
  subject(:setting) { build(:seo_page_setting) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:settable) }

  it 'keeps one setting per page record' do
    first = create(:seo_page_setting)

    expect(build(:seo_page_setting, settable: first.settable)).not_to be_valid
  end

  it 'refuses a record that has no page' do
    expect(build(:seo_page_setting, settable_type: 'Catalog::Goods::Group')).not_to be_valid
  end

  it 'stores an empty field as no field, so the template fills it' do
    expect(create(:seo_page_setting, title: '  ').title).to be_nil
  end

  it 'refuses wording about the price' do
    expect(build(:seo_page_setting, seo_text: 'Найнижча ціна в місті')).not_to be_valid
  end

  it 'goes away with its record' do
    setting = create(:seo_page_setting, settable: create(:catalog_category))

    expect { setting.settable.destroy! }.to change(described_class, :count).by(-1)
  end

  it 'stays with the record when its slug changes' do
    goods = create(:seo_page_setting, title: 'Свій заголовок').settable

    goods.update!(slug: 'inshyi-slug')

    expect(goods.reload.seo_page_setting.title).to eq('Свій заголовок')
  end
end
