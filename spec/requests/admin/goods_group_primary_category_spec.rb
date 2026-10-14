# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin: the primary category of a goods group' do
  let(:admin) { create(:admin_user) }
  let(:group) { create(:catalog_goods_group, name_uk: 'Нурофен') }
  let(:root) { create(:catalog_category, name_uk: 'Ліки') }
  let(:painkillers) { create(:catalog_category, name_uk: 'Знеболювальні', parent: root) }
  let(:antipyretics) { create(:catalog_category, name_uk: 'Жарознижувальні', parent: root) }

  def primary = group.goods_group_categories.where(is_primary: true).map(&:category)

  def history = ActiveAdmin::Comment.where(resource: group)

  def choose(category) = put primary_category_admin_goods_group_path(group), params: { category_id: category.id }

  before do
    sign_in admin
    group.goods_group_categories.create!(category: painkillers, is_primary: true)
    group.goods_group_categories.create!(category: antipyretics)
  end

  it 'lists the categories with their branches, marks the primary one and offers the other', :aggregate_failures do
    get admin_goods_group_path(group)

    expect(response.body).to include('Ліки › Знеболювальні', 'Ліки › Жарознижувальні',
                                     primary_category_admin_goods_group_path(group))
    expect(response.body.scan('Зробити головною').size).to eq(1)
  end

  it 'says the provider gave no category and offers no choice', :aggregate_failures do
    group.goods_group_categories.delete_all

    get admin_goods_group_path(group)

    expect(response.body).to include('Провайдер не задав групі жодної категорії.')
    expect(response.body).not_to include('Зробити головною')
  end

  it 'makes the chosen category primary', :aggregate_failures do
    choose(antipyretics)

    expect(response).to redirect_to(admin_goods_group_path(group))
    expect(flash[:notice]).to eq('Головну категорію змінено.')
    expect(primary).to eq([ antipyretics ])
  end

  it 'shows on the card who changed the primary category and from which branch to which' do
    choose(antipyretics)
    follow_redirect!

    expect(response.body).to include(admin.email,
                                     'Головну категорію змінено: «Ліки › Знеболювальні» → «Ліки › Жарознижувальні»')
  end

  it 'refuses a category the group does not have', :aggregate_failures do
    choose(create(:catalog_category))

    expect(flash[:alert]).to eq('Категорія не належить групі — нічого не змінено.')
    expect(primary).to eq([ painkillers ])
    expect(history).to be_empty
  end

  it 'changes nothing when a stale page asks for the category that is primary already', :aggregate_failures do
    choose(painkillers)

    expect(flash[:notice]).to eq('Ця категорія вже головна — нічого не змінено.')
    expect(history).to be_empty
  end

  it 'shows the provider as the author of a change made by an import' do
    provider = create(:provider, name: 'Pharmapoint')
    Catalog::PrimaryCategory::History.record(group:, from: painkillers, to: antipyretics, author: provider)

    get admin_goods_group_path(group)

    expect(response.body).to include('Pharmapoint', 'Головну категорію змінено: «Ліки › Знеболювальні»')
  end

  it 'has no way to add a category to a group or to take one away' do
    expect do
      post "/admin/goods_groups/#{group.id}/categories", params: { category_id: root.id }
      delete "/admin/goods_groups/#{group.id}/categories/#{painkillers.id}"
    end.not_to(change { group.goods_group_categories.count })
  end
end
