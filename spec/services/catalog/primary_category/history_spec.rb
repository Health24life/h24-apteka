# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::PrimaryCategory::History do
  let(:group) { create(:catalog_goods_group) }
  let(:root) { create(:catalog_category, name_uk: 'Ліки') }
  let(:painkillers) { create(:catalog_category, name_uk: 'Знеболювальні', parent: root) }
  let(:antipyretics) { create(:catalog_category, name_uk: 'Жарознижувальні', parent: root) }
  let(:admin) { create(:admin_user) }

  def comment = ActiveAdmin::Comment.where(resource: group).sole

  it 'names both branches from the root down when the primary category moves', :aggregate_failures do
    described_class.record(group:, from: painkillers, to: antipyretics, author: admin)

    expect(comment).to have_attributes(
      author: admin, namespace: 'admin',
      body: 'Головну категорію змінено: «Ліки › Знеболювальні» → «Ліки › Жарознижувальні»'
    )
  end

  it 'says there was no primary category before' do
    described_class.record(group:, from: nil, to: root, author: admin)

    expect(comment.body).to eq('Головною категорією зроблено «Ліки»; до цього головної не було')
  end

  it 'says no category is left when the provider took the primary one away', :aggregate_failures do
    provider = create(:provider, name: 'Pharmapoint')

    described_class.record(group:, from: painkillers, to: nil, author: provider)

    expect(comment).to have_attributes(
      author: provider, body: 'Головну категорію «Ліки › Знеболювальні» прибрано: інших категорій у групи не лишилось'
    )
  end

  it 'keeps the branch as it was written when the category is renamed later' do
    described_class.record(group:, from: painkillers, to: antipyretics, author: admin)

    antipyretics.update!(name_uk: 'Від температури')

    expect(comment.body).to end_with('«Ліки › Жарознижувальні»')
  end
end
