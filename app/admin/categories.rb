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
      row(t('admin.categories.children')) do |category|
        safe_join(category.children.sort_by(&:name_uk).map { link_to it.name_uk, resource_path(it) }, ', ')
      end
      row(:slug) { |category| seo_front_link(category) }
      row :created_at
      row :updated_at
    end

    panel t('admin.categories.goods_groups', count: Catalog::Goods::Group.in_branch(resource.id).count) do
      # The newest groups of the branch only: a big branch has thousands, and the full list is one link away.
      links = Catalog::Goods::Group::Category.where(category: resource.self_and_descendants)
                                             .includes(:category, goods_group: :translations)
                                             .order(goods_group_id: :desc).limit(20)
      if links.empty?
        para t('admin.categories.no_goods_groups')
      else
        table_for links do
          column(Catalog::Goods::Group.human_attribute_name(:name)) do |link|
            link_to link.goods_group.name_uk, admin_goods_group_path(link.goods_group)
          end
          column(Catalog::Category.model_name.human) do |link|
            category = link.category
            category == resource ? category.name_uk : link_to(category.name_uk, resource_path(category))
          end
          column(t('admin.primary_category.primary')) { |link| status_tag(link.is_primary) }
          column(Catalog::Goods::Group.human_attribute_name(:withdrawn)) { |link| status_tag(link.goods_group.withdrawn) }
          column(Catalog::Goods::Group.human_attribute_name(:hidden)) { |link| status_tag(link.goods_group.hidden) }
        end
        para link_to(t('admin.categories.all_goods_groups'), admin_goods_groups_path(q: { in_branch: resource.id }))
      end
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
