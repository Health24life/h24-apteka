# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Templates::Pick do
  let(:root) { create(:catalog_category) }
  let(:painkillers) { create(:catalog_category, parent: root) }
  let(:leaf) { create(:catalog_category, parent: painkillers) }
  let!(:general) { create(:seo_template) }

  def pick(category: leaf, recipe: false) = described_class.call(page_type: 'goods', category:, recipe:)

  it 'takes the general template when nothing narrower fits', :aggregate_failures do
    expect(pick).to eq(general)
    expect(pick(category: nil)).to eq(general)
  end

  it 'takes the template of the branch over the general one' do
    branch = create(:seo_template, category: painkillers)

    expect(pick).to eq(branch)
  end

  it 'takes the template of the nearest category of the branch' do
    create(:seo_template, category: root)
    nearest = create(:seo_template, category: painkillers)

    expect(pick).to eq(nearest)
  end

  it 'ignores a template of another branch' do
    create(:seo_template, category: create(:catalog_category))

    expect(pick).to eq(general)
  end

  it 'takes the template for the prescription kind within the same branch', :aggregate_failures do
    create(:seo_template, category: painkillers)
    prescription = create(:seo_template, category: painkillers, is_recipe: true)

    expect(pick(recipe: true)).to eq(prescription)
    expect(pick(recipe: false)).not_to eq(prescription)
  end

  it 'puts the branch before the prescription kind' do
    create(:seo_template, is_recipe: true)
    branch = create(:seo_template, category: painkillers)

    expect(pick(recipe: true)).to eq(branch)
  end

  it 'takes only the general templates for a product whose group has no main category' do
    create(:seo_template, category: painkillers)

    expect(pick(category: nil)).to eq(general)
  end

  it 'never narrows down other kinds of pages by prescription' do
    cart = create(:seo_template, page_type: 'cart', title: 'Кошик', description: 'Кошик', h1: 'Кошик')

    expect(described_class.call(page_type: 'cart')).to eq(cart)
  end

  it 'says so when a page type has no general template' do
    expect { described_class.call(page_type: 'order') }.to raise_error(described_class::Missing, /order/)
  end
end
