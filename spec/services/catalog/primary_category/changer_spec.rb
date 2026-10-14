# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::PrimaryCategory::Changer do
  let(:admin) { create(:admin_user) }
  let(:group) { create(:catalog_goods_group) }
  let(:root) { create(:catalog_category, name_uk: 'Ліки') }
  let(:painkillers) { create(:catalog_category, name_uk: 'Знеболювальні', parent: root) }
  let(:antipyretics) { create(:catalog_category, name_uk: 'Жарознижувальні', parent: root) }

  def comments = ActiveAdmin::Comment.where(resource: group)

  def link(category, primary: false) = group.goods_group_categories.create!(category:, is_primary: primary)

  def change_to(category) = described_class.call(group:, category_id: category.id, admin:)

  def primary = group.goods_group_categories.where(is_primary: true).map(&:category)

  context 'with a primary category' do
    before do
      link(painkillers, primary: true)
      link(antipyretics)
    end

    it 'moves the mark to the chosen category and keeps the set of categories', :aggregate_failures do
      expect(change_to(antipyretics)).to eq(:changed)
      expect(primary).to eq([ antipyretics ])
      expect(group.reload.categories).to contain_exactly(painkillers, antipyretics)
    end

    it 'records who moved it and from which branch to which' do
      change_to(antipyretics)

      expect(comments.sole).to have_attributes(
        author: admin, body: 'Головну категорію змінено: «Ліки › Знеболювальні» → «Ліки › Жарознижувальні»'
      )
    end

    it 'moves the date the group changed on, which the sitemap dates its SKU by' do
      group.update_columns(updated_at: 1.day.ago) # rubocop:disable Rails/SkipsModelValidations

      expect { change_to(antipyretics) }.to(change { group.reload.updated_at })
    end

    it 'changes nothing and records nothing for the category that is primary already', :aggregate_failures do
      expect(change_to(painkillers)).to eq(:unchanged)
      expect(primary).to eq([ painkillers ])
      expect(comments).to be_empty
    end

    it 'refuses a category the group does not have and changes nothing', :aggregate_failures do
      expect(change_to(create(:catalog_category))).to eq(:not_in_group)
      expect(primary).to eq([ painkillers ])
      expect(comments).to be_empty
    end

    it 'gives way to a primary marked in between by an import and records nothing', :aggregate_failures do
      third = link(create(:catalog_category)).category
      sneak_in_after_unmark(third)

      expect(change_to(antipyretics)).to eq(:conflict)
      expect(primary).to eq([ third ])
      expect(comments).to be_empty
    end
  end

  it 'marks the chosen category of a group that has no primary one', :aggregate_failures do
    link(painkillers)
    link(antipyretics)

    expect(change_to(painkillers)).to eq(:changed)
    expect(primary).to eq([ painkillers ])
    expect(comments.sole.body).to eq('Головною категорією зроблено «Ліки › Знеболювальні»; до цього головної не було')
  end

  # Stands in for an import that marks the first category of its list while the group is left without a primary one.
  def sneak_in_after_unmark(category)
    allow_any_instance_of(Catalog::Goods::Group::Category).to receive(:update!).and_wrap_original do |original, **attrs| # rubocop:disable RSpec/AnyInstance
      original.call(**attrs).tap do
        next if attrs[:is_primary]

        group.goods_group_categories.where(category:).update_all(is_primary: true) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
