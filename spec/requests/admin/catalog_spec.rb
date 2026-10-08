# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin catalog' do
  let(:admin) { create(:admin_user) }
  let(:provider) { create(:provider, name: 'Pharmapoint') }
  let(:group) { create(:catalog_goods_group, name_uk: 'Аспірин', producer: create(:catalog_producer, name: 'Bayer')) }
  let(:goods) { create(:catalog_goods, goods_group: group, name_uk: 'Аспірин 500 мг №10') }
  let(:drugstore) do
    create(:catalog_drugstore, name: 'Аптека на Хрещатику', drugstore_legal_entity_code: '38001234',
                               drugstore_legal_entity_name: 'ТОВ «Здоров’я»')
  end

  before { sign_in admin }

  describe 'lists and cards' do
    it 'lists goods groups with their producer' do
      group

      get admin_goods_groups_path

      expect(response.body).to include('Аспірин', 'Bayer')
    end

    it 'lists goods and drugstores', :aggregate_failures do
      [ goods, drugstore ]

      get admin_skus_path
      expect(response.body).to include('Аспірин 500 мг №10')
      get admin_drugstores_path
      expect(response.body).to include('Аптека на Хрещатику', '38001234')
    end

    it 'shows a goods group with its goods and its link to the provider', :aggregate_failures do
      create(:provider_link, provider:, linkable: group, external_id: '122c4abff4ae26d0068e7b4cfce236a6')
      goods

      get admin_goods_group_path(group)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Bayer', 'Аспірин 500 мг №10', 'Pharmapoint', '122c4abff4ae26d0068e7b4cfce236a6')
    end

    it 'shows goods with the sections of its instruction in their order' do
      create(:catalog_goods_instruction_section, goods:, position: 2, code: 'sklad', anchor: 'sklad')
      create(:catalog_goods_instruction_section, goods:, position: 1, code: 'pokazannia', anchor: 'pokazannia')

      get admin_sku_path(goods)

      expect(response.body).to match(/Показання.*Склад/m)
    end

    it 'shows a drugstore with its legal entity, address, coordinates and hours', :aggregate_failures do
      create(:catalog_drugstore_address, drugstore:, address: 'вул. Хрещатик, 1', latitude: 50.45, longitude: 30.52)

      get admin_drugstore_path(drugstore)

      expect(response.body).to include('ТОВ «Здоров’я»', '38001234', 'вул. Хрещатик, 1', '50.45', '30.52')
      expect(response.body).to include('1: 08:00-21:00')
    end

    it 'filters goods by name', :aggregate_failures do
      other = create(:catalog_goods, name_uk: 'Парацетамол')
      goods

      get admin_skus_path, params: { q: { name_cont: 'аспір' } }

      expect(response.body).to include(goods.name)
      expect(response.body).not_to include(other.name)
    end

    it 'filters goods by the hidden flag', :aggregate_failures do
      other = create(:catalog_goods, name_uk: 'Парацетамол', hidden: true)
      goods

      get admin_skus_path, params: { q: { hidden_eq: true } }

      expect(response.body).to include(other.name)
      expect(response.body).not_to include(goods.name)
    end

    it 'filters drugstores by the legal entity code', :aggregate_failures do
      other = create(:catalog_drugstore, name: 'Інша аптека', drugstore_legal_entity_code: '12345678')
      drugstore

      get admin_drugstores_path, params: { q: { drugstore_legal_entity_code_cont: '3800' } }

      expect(response.body).to include(drugstore.name)
      expect(response.body).not_to include(other.name)
    end
  end

  describe 'no changes to the partner data' do
    it 'has no way to edit goods' do
      put admin_sku_path(goods), params: { catalog_goods: { name_uk: 'Інше' } }

      expect(response).to have_http_status(:not_found)
    end

    it 'has no way to delete a drugstore or to open an edit form', :aggregate_failures do
      delete admin_drugstore_path(drugstore)
      expect(response).to have_http_status(:not_found)
      get "/admin/goods_groups/#{group.id}/edit"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'hiding and showing' do
    it 'offers to hide a shown record and to show a hidden one', :aggregate_failures do
      get admin_sku_path(goods)
      expect(response.body).to include(visibility_admin_sku_path(goods), 'Приховати')

      goods.update!(hidden: true)
      get admin_sku_path(goods)
      expect(response.body).to include('Показати')
    end

    it 'asks for the reason before hiding' do
      get visibility_admin_drugstore_path(drugstore)

      expect(response.body).to include('Приховати з вітрини', 'name="reason"')
    end

    it 'hides a record with a reason and shows who did it and why on its card', :aggregate_failures do
      put visibility_admin_goods_group_path(group), params: { hidden: true, reason: 'скарга на опис' }

      expect(response).to redirect_to(admin_goods_group_path(group))
      expect(group.reload.hidden).to be(true)
      follow_redirect!
      expect(response.body).to include('Приховано з вітрини. Причина: скарга на опис', admin.email)
    end

    it 'refuses to hide without a reason', :aggregate_failures do
      put visibility_admin_sku_path(goods), params: { hidden: true, reason: ' ' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Вкажіть причину')
      expect(goods.reload.hidden).to be(false)
    end

    it 'shows a hidden record without a reason', :aggregate_failures do
      drugstore.update!(hidden: true)

      put visibility_admin_drugstore_path(drugstore), params: { hidden: false }

      expect(drugstore.reload.hidden).to be(false)
      expect(ActiveAdmin::Comment.where(resource: drugstore).sole.body).to eq('Повернуто на вітрину')
    end

    it 'changes nothing when a stale page asks for the state the record is already in', :aggregate_failures do
      goods.update!(hidden: true)

      put visibility_admin_sku_path(goods), params: { hidden: true, reason: 'ще раз' }

      expect(flash[:notice]).to eq('Запис уже в цьому стані — нічого не змінено.')
      expect(ActiveAdmin::Comment.where(resource: goods)).to be_empty
    end
  end
end
