# frozen_string_literal: true

ActiveAdmin.register Catalog::Goods, as: 'Sku' do
  menu parent: 'catalog', priority: 2

  actions :index, :show
  config.batch_actions = false
  config.sort_order = 'id_desc'

  includes :translations, goods_group: :translations

  # The SKUs a template of the given branch and prescription kind applies to, for its preview.
  searchable_select_options(
    name: :preview,
    scope: ->(params) { Seo::Templates::Preview.options('goods', params) },
    display_text: ->(goods) { goods.name_uk },
    filter: ->(term, scope) { scope.name_cont(term) }
  )

  filter :name_cont, as: :string, label: proc { Catalog::Goods.human_attribute_name(:name) }
  filter :morion_code
  filter :withdrawn
  filter :hidden
  filter :is_recipe
  filter :created_at

  index do
    id_column
    column :name
    column :goods_group
    column :morion_code
    column :withdrawn
    column :hidden
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :goods_group
      row :mnn
      row :dosage
      row :release_form
      row :form
      row :measure
      row :pack_quantity_in_pack
      row :pack_unit_name
      row :morion_code
      row :is_recipe
      row :is_strict_recipe
      row :in_medication_program
      row :composition
      row(:image_paths) { |goods| goods.image_paths.join(', ') }
      row :slug
      row :withdrawn
      row :hidden
      row :created_at
      row :updated_at
    end

    panel Catalog::Goods.human_attribute_name(:instruction_sections) do
      table_for resource.instruction_sections do
        column(:position)
        column(:title)
        column(:anchor)
      end
    end

    render 'admin/seo_override', record: resource
    render 'admin/provider_links', record: resource
    render 'admin/seo_history', record: resource
    active_admin_comments_for resource
  end

  action_item :seo, only: :show do
    link_to t('admin.seo_override.edit'), url_for(action: :seo), class: 'action-item-button'
  end

  action_item :slug, only: :show do
    link_to t('admin.slug.change'), url_for(action: :slug), class: 'action-item-button'
  end

  member_action :seo, method: %i[get put] do
    change_seo_override
  end

  member_action :slug, method: %i[get put] do
    change_slug
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
    include SeoOverrideActions
    include SlugChangeActions
  end
end
