# frozen_string_literal: true

ActiveAdmin.register Seo::StaticPage, as: 'StaticPage' do
  menu parent: 'SEO', priority: 1

  config.batch_actions = false
  config.sort_order = 'id_asc'
  config.filters = false

  searchable_select_options(name: :preview, scope: -> { Seo::StaticPage.pages.order(:id) },
                            display_text: lambda(&:name_uk), filter: ->(term, scope) { scope.name_cont(term) })

  permit_params do
    params = %i[name_uk content_uk published]
    action_name == 'create' ? params + [ :slug ] : params
  end

  index do
    id_column
    column(:name) { |page| link_to page.name_uk, resource_path(page) }
    column(t('admin.static_pages.front_url')) { |page| seo_front_url(page) }
    column :published
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :id
      row(:name, &:name_uk)
      row(t('admin.static_pages.front_url')) { |page| seo_front_url(page) }
      row :published unless resource.home?
      row :updated_at
    end

    if resource.home?
      para t('admin.static_pages.home')
    else
      panel t('admin.static_pages.as_front') do
        div(class: 'trix-content') { resource.content_uk.to_s.html_safe } # rubocop:disable Rails/OutputSafety
      end
    end

    render 'admin/seo_override', record: resource
    render 'admin/seo_history', record: resource
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs do
      f.input :name_uk
      f.input :slug, required: false, hint: t('admin.static_pages.slug_hint') if f.object.new_record?
      f.input :published
      f.input :content_uk, as: :rich_text
    end
    f.actions
  end

  action_item :seo, only: :show do
    link_to t('admin.seo_override.edit'), url_for(action: :seo), class: 'action-item-button'
  end

  action_item :slug, only: :show, if: proc { !resource.home? } do
    link_to t('admin.slug.change'), url_for(action: :slug), class: 'action-item-button'
  end

  member_action :seo, method: %i[get put] do
    change_seo_override
  end

  member_action :slug, method: %i[get put] do
    change_slug
  end

  after_save do |page|
    flash[:warning] = t('admin.static_pages.sanitized') if page.html_sanitized?
  end

  controller do
    include SeoOverrideActions
    include SlugChangeActions
  end
end
