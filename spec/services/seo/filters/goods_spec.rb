# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Filters::Goods do
  let(:vitamins) { create(:catalog_category, name_uk: 'Вітаміни') }
  let(:capsules) { create(:catalog_goods_form, name_uk: 'Капсули') }
  let(:tablets) { create(:catalog_goods_form, name_uk: 'Таблетки') }

  def sku(category: vitamins, group: {}, **goods)
    group = create(:catalog_goods_group, **group)
    create(:catalog_goods_group_category, goods_group: group, category:) if category
    create(:catalog_goods, goods_group: group, **goods)
  end

  def selected(params, **filter) = described_class.call(build(:seo_filter, params:, **filter))

  it 'selects the goods that match every parameter' do
    vitamin_d = sku(form: capsules)
    sku(form: tablets)
    sku(category: create(:catalog_category), form: capsules)

    expect(selected({ 'category_id' => [ vitamins.id ], 'form_id' => [ capsules.id ] })).to eq([ vitamin_d ])
  end

  it 'takes any of the values of a parameter' do
    goods = [ sku(form: capsules), sku(form: tablets) ]
    sku(form: create(:catalog_goods_form))

    expect(selected({ 'form_id' => [ capsules.id, tablets.id ] })).to match_array(goods)
  end

  it 'takes in the goods of the subcategories of a category, by any link of their group' do
    kids = create(:catalog_category, parent: vitamins)
    goods = sku(category: kids)

    expect(selected({ 'category_id' => [ vitamins.id ] })).to eq([ goods ])
  end

  it 'selects by the producer of the group' do
    bayer = create(:catalog_producer, name: 'Bayer')
    goods = sku(group: { producer: bayer })
    sku

    expect(selected({ 'producer_id' => [ bayer.id ] })).to eq([ goods ])
  end

  it 'selects by a restriction' do
    allowed = create(:catalog_goods_restriction, name_uk: 'Дозволено')
    goods = sku(child_restriction: allowed)
    sku(child_restriction: create(:catalog_goods_restriction, name_uk: 'Заборонено'))

    expect(selected({ 'child_restriction_id' => [ allowed.id ] })).to eq([ goods ])
  end

  it 'leaves out the goods off the storefront, hidden or withdrawn, with their group too' do
    [ { hidden: true }, { withdrawn: true } ].each do |state|
      sku(**state)
      sku(group: state)
    end

    expect(selected({ 'category_id' => [ vitamins.id ] })).to be_empty
  end

  describe 'the prescription scope' do
    let!(:otc) { sku(is_recipe: false) }
    let!(:rx) { sku(is_recipe: true) }

    def params = { 'category_id' => [ vitamins.id ] }

    it 'keeps to the goods without a prescription by default' do
      expect(selected(params)).to eq([ otc ])
    end

    it 'keeps to the prescription goods or takes all as the filter says', :aggregate_failures do
      expect(selected(params, recipe_scope: 'rx')).to eq([ rx ])
      expect(selected(params, recipe_scope: 'any')).to contain_exactly(otc, rx)
    end
  end

  it 'tells whether a filter selects anything', :aggregate_failures do
    sku(form: capsules)

    expect(described_class.any?(build(:seo_filter, params: { 'form_id' => [ capsules.id ] }))).to be(true)
    expect(described_class.any?(build(:seo_filter, params: { 'form_id' => [ tablets.id ] }))).to be(false)
  end
end
