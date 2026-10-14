# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Override do
  subject(:override) { build(:seo_override) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:target) }

  it 'keeps one override per page record' do
    first = create(:seo_override)

    expect(build(:seo_override, target: first.target)).not_to be_valid
  end

  it 'refuses a record that has no page of its own' do
    expect(build(:seo_override, target_type: 'Catalog::Goods::Group')).not_to be_valid
  end

  it 'follows the rules of the page for robots unless told otherwise', :aggregate_failures do
    expect(override.robots).to eq('auto')
    expect(build(:seo_override, robots: 'sometimes')).not_to be_valid
  end

  it 'stores the short texts by language in the row and the SEO text in a translation', :aggregate_failures do
    saved = create(:seo_override, title_uk: 'Нурофен: інструкція', seo_text_uk: '<p>Текст</p>')

    expect(saved.read_attribute(:title)).to eq('uk' => 'Нурофен: інструкція')
    expect(saved.translations.sole).to have_attributes(locale: 'uk', seo_text: '<p>Текст</p>')
  end

  it 'refuses wording about the price in the SEO text' do
    expect(build(:seo_override, seo_text_uk: 'Найнижча ціна в місті')).not_to be_valid
  end

  it 'goes away with its record, the SEO text included', :aggregate_failures do
    override = create(:seo_override, target: create(:catalog_category), seo_text_uk: 'Текст')

    expect { override.target.destroy! }.to change(described_class, :count).by(-1)
    expect(Seo::Override::Translation.count).to eq(0)
  end

  it 'stays with the record when its slug changes' do
    goods = create(:seo_override, title_uk: 'Свій заголовок').target

    goods.update!(slug: 'inshyi-slug')

    expect(goods.reload.seo_override.title).to eq('Свій заголовок')
  end
end

# == Schema Information
#
# Table name: seo_overrides
#
#  id          :bigint           not null, primary key
#  description :jsonb            not null
#  h1          :jsonb            not null
#  robots      :string           default("auto"), not null
#  target_type :string           not null
#  title       :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  target_id   :bigint           not null
#
# Indexes
#
#  index_seo_overrides_on_target  (target_type,target_id) UNIQUE
#
# Check Constraints
#
#  seo_overrides_robots_check  (robots::text = ANY (ARRAY['auto'::character varying, 'index'::character varying, 'noindex'::character varying]::text[]))
#
