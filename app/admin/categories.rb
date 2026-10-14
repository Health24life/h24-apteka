# frozen_string_literal: true

ActiveAdmin.register Catalog::Category, as: 'Category' do
  menu parent: 'catalog', priority: 3

  actions :index, :show
  config.batch_actions = false
  config.sort_order = 'id_asc'

  searchable_select_options(scope: -> { Catalog::Category.order(:id) }, display_text: lambda(&:branch_name),
                            filter: ->(term, scope) { scope.name_cont(term) })
  # The categories a template of the given branch applies to, for its preview.
  searchable_select_options(
    name: :preview,
    scope: ->(params) { Seo::Templates::Preview.options('category', params) },
    display_text: ->(category) { category.branch_name },
    filter: ->(term, scope) { scope.name_cont(term) }
  )

  filter :name_cont, as: :string, label: proc { Catalog::Category.human_attribute_name(:name) }
  filter :slug_cont, as: :string, label: proc { Catalog::Category.human_attribute_name(:slug) }

  index do
    id_column
    column(Catalog::Category.human_attribute_name(:branch)) do |category|
      link_to category.branch_name, resource_path(category)
    end
    column :slug
    actions
  end

  show do
    attributes_table do
      row :id
      row(:name, &:name_uk)
      row(Catalog::Category.human_attribute_name(:branch), &:branch_name)
      row :parent
      row(:slug) do |category|
        link_to seo_front_url(category), seo_front_url(category), target: '_blank', rel: 'noopener'
      end
      row :created_at
      row :updated_at
    end

    render 'admin/seo_override', record: resource
    render 'admin/seo_history', record: resource
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

  controller do
    include SeoOverrideActions
    include SlugChangeActions
  end
end
