# frozen_string_literal: true

ActiveAdmin.register Catalog::Drugstore, as: 'Drugstore' do
  menu parent: 'catalog', priority: 3

  actions :index, :show
  config.batch_actions = false
  config.sort_order = 'id_desc'

  includes :brand, :address

  filter :name
  filter :drugstore_legal_entity_code
  filter :brand, as: :tom_select
  filter :incomplete
  filter :withdrawn
  filter :hidden
  filter :work_with_reimbursement
  filter :created_at

  index do
    id_column
    column :name
    column :brand
    column(:address) { |drugstore| drugstore.address&.address }
    column :drugstore_legal_entity_code
    column :incomplete
    column :withdrawn
    column :hidden
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :brand
      row :drugstore_legal_entity_name
      row :drugstore_legal_entity_code
      row(:address) { |drugstore| drugstore.address&.address }
      row(:coordinates) do |drugstore|
        drugstore.address && "#{drugstore.address.latitude}, #{drugstore.address.longitude}"
      end
      row(:week_working_hours) do |drugstore|
        drugstore.week_working_hours.each_with_index.map { |day, index| "#{index + 1}: #{day || '—'}" }.join(' · ')
      end
      row :phone
      row :mobile_phone
      row :email
      row :work_with_reimbursement
      row :incomplete
      row :withdrawn
      row :hidden
      row :created_at
      row :updated_at
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
