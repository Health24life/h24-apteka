# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Template do
  subject(:template) { build(:seo_template) }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:category).optional }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:description) }
  it { is_expected.to validate_presence_of(:h1) }

  it 'refuses a page type outside the scheme' do
    expect(build(:seo_template, page_type: 'search')).not_to be_valid
  end

  it 'refuses a second template for the same page type, branch and prescription', :aggregate_failures do
    category = create(:catalog_category)
    create(:seo_template, category:, is_recipe: true)

    expect(build(:seo_template, category:, is_recipe: true)).not_to be_valid
    expect(build(:seo_template, category:)).to be_valid
  end

  it 'refuses a second general template of a page type' do
    create(:seo_template)

    expect(build(:seo_template)).not_to be_valid
  end

  it 'refuses a second general template at the database level' do
    create(:seo_template)

    expect { build(:seo_template).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'narrows down by a branch only the category and product templates', :aggregate_failures do
    category = create(:catalog_category)

    expect(build(:seo_template, page_type: 'category', category:, title: '{name}')).to be_valid
    expect(build(:seo_template, page_type: 'cart', category:, title: 'Кошик', description: 'Кошик', h1: 'Кошик'))
      .not_to be_valid
  end

  it 'narrows down by prescription only the product templates', :aggregate_failures do
    expect(build(:seo_template, is_recipe: false)).to be_valid
    expect(build(:seo_template, page_type: 'category', is_recipe: true, title: '{name}', description: '{name}'))
      .not_to be_valid
  end

  it 'refuses a placeholder the page type does not know', :aggregate_failures do
    category_template = build(:seo_template, page_type: 'category', title: '{name} {dosage}')

    expect(category_template).not_to be_valid
    expect(category_template.errors).to be_added(:title, :unknown_placeholders, placeholders: '{dosage}')
  end

  it 'refuses wording that calls to buy', :aggregate_failures do
    template = build(:seo_template, description: 'Купити {name} недорого')

    expect(template).not_to be_valid
    expect(template.errors).to be_added(:description, :not_neutral, words: 'купити')
  end

  describe 'removal' do
    it 'keeps the general template of a page type', :aggregate_failures do
      general = create(:seo_template)

      expect(general.destroy).to be(false)
      expect(general.errors).to be_added(:base, :general_template_required)
    end

    it 'removes a narrower template' do
      narrower = create(:seo_template, is_recipe: true)

      expect { narrower.destroy }.to change(described_class, :count).by(-1)
    end

    it 'goes away with the category of its branch' do
      category = create(:catalog_category)
      create(:seo_template, category:)

      expect { category.destroy! }.to change(described_class, :count).by(-1)
    end
  end
end
