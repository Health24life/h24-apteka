# frozen_string_literal: true

ActiveAdmin.register Catalog::Goods::Group, as: 'GoodsGroup' do
  menu parent: 'catalog', priority: 1

  actions :index, :show
  config.batch_actions = false
  config.sort_order = 'id_desc'

  includes :producer, :translations

  filter :name_cont, as: :string, label: proc { Catalog::Goods::Group.human_attribute_name(:name) }
  filter :withdrawn
  filter :hidden
  filter :created_at

  index do
    id_column
    column :name
    column :producer
    column :withdrawn
    column :hidden
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :producer
      row :goods_name
      row(:atc_class) { |group| group.atc_class && [ group.atc_class.code, group.atc_class.name ].compact.join(' — ') }
      row(:categories) { |group| group.categories.map(&:name).join(', ') }
      row :included_to_offers
      row :withdrawn
      row :hidden
      row :created_at
      row :updated_at
    end

    panel t('activerecord.models.sku.other') do
      table_for resource.goods.includes(:translations).order(:id) do
        column(Catalog::Goods.human_attribute_name(:name)) { |goods| link_to goods.name, admin_sku_path(goods) }
        column(Catalog::Goods.human_attribute_name(:withdrawn), &:withdrawn)
        column(Catalog::Goods.human_attribute_name(:hidden), &:hidden)
      end
    end

    render 'admin/provider_links', record: resource
    active_admin_comments_for resource
  end

  action_item :visibility, only: :show do
    link_to t(resource.hidden ? 'admin.visibility.show' : 'admin.visibility.hide'),
            url_for(action: :visibility), class: 'action-item-button'
  end

  member_action :visibility, method: %i[get put] do
    change_visibility
  end

  controller do
    include CatalogVisibilityActions
  end
end
