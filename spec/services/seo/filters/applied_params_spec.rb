# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Filters::AppliedParams do
  let(:slimming) { create(:catalog_category, name_uk: 'Засоби для схуднення') }
  let(:capsules) { create(:catalog_goods_form, name_uk: 'Капсули') }
  let(:tablets) { create(:catalog_goods_form, name_uk: 'Таблетки') }

  def applied(params) = described_class.call(build(:seo_filter, params:)).map(&:to_h)

  it 'names each parameter and its values in the order of the parameters and of the ids' do
    expect(applied({ 'form_id' => [ tablets.id, capsules.id ], 'category_id' => [ slimming.id ] })).to eq(
      [ { key: 'category_id', name: 'Категорія', values: [ { id: slimming.id, name: 'Засоби для схуднення' } ] },
        { key: 'form_id', name: 'Форма випуску',
          values: [ { id: tablets.id, name: 'Таблетки' }, { id: capsules.id, name: 'Капсули' } ] } ]
    )
  end

  it 'names a producer and a restriction' do
    producer = create(:catalog_producer, name: 'Bayer')
    allowed = create(:catalog_goods_restriction, name_uk: 'Дозволено')

    expect(applied({ 'producer_id' => [ producer.id ], 'child_restriction_id' => [ allowed.id ] }).pluck(:values))
      .to eq([ [ { id: producer.id, name: 'Bayer' } ], [ { id: allowed.id, name: 'Дозволено' } ] ])
  end

  it 'leaves out an id whose record is gone, and a parameter left without values', :aggregate_failures do
    expect(applied({ 'form_id' => [ capsules.id,
                                    999_999 ] }).sole[:values]).to eq([ { id: capsules.id, name: 'Капсули' } ])
    expect(applied({ 'producer_id' => [ 999_999 ] })).to eq([])
  end

  it 'gives nothing for a filter without parameters' do
    expect(applied({})).to eq([])
  end
end
