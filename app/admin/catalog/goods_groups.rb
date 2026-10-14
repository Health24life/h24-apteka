# frozen_string_literal: true

ActiveAdmin.register Catalog::Goods::Group, as: 'GoodsGroup' do
  menu parent: 'catalog', priority: 1

  actions :index, :show
  config.batch_actions = false
  config.sort_order = 'id_desc'

  includes :producer, :translations

  filter :name_cont, as: :string, label: proc { Catalog::Goods::Group.human_attribute_name(:name) }
  filter :in_branch, as: :tom_select, label: proc { I18n.t('admin.categories.branch_filter') },
                     ajax: { resource: Catalog::Category }
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
      row :included_to_offers
      row :withdrawn
      row :hidden
      row :created_at
      row :updated_at
    end

    panel Catalog::Goods::Group.human_attribute_name(:categories) do
      links = resource.goods_group_categories.includes(:category).sort_by { it.category.branch_name }
      if links.empty?
        para t('admin.primary_category.none')
      else
        table_for links do
          column(t('admin.primary_category.branch')) { |link| link.category.branch_name }
          column(t('admin.primary_category.primary')) do |link|
            if link.is_primary
              status_tag t('admin.primary_category.primary'), class: 'yes'
            else
              button_to t('admin.primary_category.make_primary'), url_for(action: :primary_category),
                        method: :put, params: { category_id: link.category_id }, class: 'action-item-button',
                        data: { confirm: t('admin.primary_category.confirm', branch: link.category.branch_name) }
            end
          end
        end
      end
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

  member_action :primary_category, method: :put do
    result = Catalog::PrimaryCategory::Changer.call(group: resource, category_id: params.require(:category_id),
                                                    admin: current_admin_user)
    kind = %i[changed unchanged].include?(result) ? :notice : :alert
    redirect_to resource_path(resource), kind => t("admin.primary_category.#{result}")
  end

  controller do
    include CatalogVisibilityActions
  end
end
