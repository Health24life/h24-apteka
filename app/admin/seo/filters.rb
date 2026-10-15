# frozen_string_literal: true

ActiveAdmin.register Seo::Filter, as: 'SeoFilter' do
  menu parent: 'SEO', priority: 2

  actions :all, except: :destroy
  config.batch_actions = false
  config.sort_order = 'position_asc'

  includes :category

  # Producers are thousands, so their select searches; they have no admin resource of their own.
  searchable_select_options(
    name: :producers, scope: -> { Catalog::Producer.order(:name) }, display_text: lambda(&:name),
    filter: ->(term, scope) { scope.where('catalog_producers.name ILIKE ?', "%#{scope.sanitize_sql_like(term)}%") }
  )
  # The filters a template of a filter page can be tried on.
  searchable_select_options(
    name: :preview, scope: -> { Seo::Templates::Preview.options('filter', {}).order(:id) },
    display_text: lambda(&:name_uk),
    filter: ->(term, scope) { scope.where("seo_filters.name->>'uk' ILIKE ?", "%#{scope.sanitize_sql_like(term)}%") }
  )

  permit_params do
    fields = [ :name_uk, :category_id, :position, :sort_order, :recipe_scope,
               { params: Seo::Filter::PARAMS.keys.index_with { [] } } ]
    action_name == 'create' ? fields + [ :slug ] : fields
  end

  scope :all, default: true
  scope(proc { I18n.t('admin.seo_filters.states.draft') }, :drafts) { it.where(published: false, removed_at: nil) }
  scope(proc { I18n.t('admin.seo_filters.states.published') }, :published) { it.where(published: true) }
  scope(proc { I18n.t('admin.seo_filters.states.removed') }, :removed) { it.where.not(removed_at: nil) }

  filter :category, as: :tom_select, ajax: { resource: Catalog::Category }

  # A published filter with no goods is a page closed to search engines; its row stands out so the editor sees it.
  index row_html: ->(filter) { { class: 'seo-filter-empty' } if SeoFilterAdminHelper.empty?(filter) } do
    column(:name) { |filter| link_to filter.name_uk, resource_path(filter) }
    column(t('admin.static_pages.front_url')) { |filter| seo_front_link(filter) }
    column(:category) { |filter| filter.category&.branch_name }
    column :position
    column(t('admin.seo_filters.state')) { |filter| seo_filter_state(filter) }
    actions
  end

  show do
    attributes_table do
      row(:name, &:name_uk)
      row(t('admin.static_pages.front_url')) { |filter| seo_front_link(filter) }
      row(t('admin.seo_filters.state')) { |filter| seo_filter_state(filter) }
      row(:category) { |filter| filter.category&.branch_name }
      row :position
      row(:sort_order) { |filter| t(filter.sort_order, scope: 'admin.seo_filters.sort_orders') }
      row(:recipe_scope) { |filter| t(filter.recipe_scope, scope: 'admin.seo_filters.recipe_scopes') }
      row(t('admin.seo_filters.params')) { |filter| seo_filter_applied_params(filter) }
      row :updated_at
    end

    panel t('admin.seo_filters.goods_now') do
      render 'admin/seo/filter_preview', preview: Seo::Filters::Preview.call(resource)
    end
    render 'admin/seo_override', record: resource unless resource.removed?
    render 'admin/seo_history', record: resource
  end

  form do |f|
    filter = f.object
    f.semantic_errors(*filter.errors.attribute_names)
    f.inputs do
      f.input :name_uk
      f.input :slug, required: false, hint: t('admin.static_pages.slug_hint') if filter.new_record?
      f.input :category, as: :tom_select, ajax: { resource: Catalog::Category },
                         hint: t('admin.seo_filters.category_hint')
      f.input :position, hint: t('admin.seo_filters.position_hint')
      f.input :sort_order, as: :select, include_blank: false,
                           collection: Seo::Filter.sort_orders.keys.map { [ t(it, scope: 'admin.seo_filters.sort_orders'), it ] }
      f.input :recipe_scope, as: :select, include_blank: false,
                             collection: Seo::Filter.recipe_scopes.keys.map { [ t(it, scope: 'admin.seo_filters.recipe_scopes'), it ] }
    end
    f.inputs t('admin.seo_filters.params') do
      f.semantic_fields_for :params, seo_filter_params_form(filter) do |selection|
        Seo::Filter::PARAMS.each_key { |key| selection.input key, **seo_filter_param_input(key) }
      end
    end
    if seo_preview
      f.inputs t('admin.seo_filters.goods_now') do
        render 'admin/seo/filter_preview', preview: seo_preview
      end
    end
    f.actions do
      f.action :submit
      f.action :submit, label: t('admin.seo_filters.preview'), button_html: { name: 'preview' }
      f.cancel_link
    end
  end

  action_item :publish, only: :show, if: proc { authorized?(:publish, resource) } do
    action = resource.published? ? :unpublish : :publish
    link_to t("admin.seo_filters.#{action}"), url_for(action:), method: :put, class: 'action-item-button'
  end

  action_item :seo, only: :show, if: proc { authorized?(:seo, resource) } do
    link_to t('admin.seo_override.edit'), url_for(action: :seo), class: 'action-item-button'
  end

  action_item :slug, only: :show, if: proc { authorized?(:slug, resource) } do
    link_to t('admin.slug.change'), url_for(action: :slug), class: 'action-item-button'
  end

  action_item :remove, only: :show, if: proc { authorized?(:remove, resource) } do
    link_to t('admin.seo_filters.remove'), url_for(action: :remove), class: 'action-item-button'
  end

  action_item :restore, only: :show, if: proc { authorized?(:restore, resource) } do
    link_to t('admin.seo_filters.restore'), url_for(action: :restore),
            method: :put, class: 'action-item-button', data: { confirm: t('admin.seo_filters.restore_confirm') }
  end

  member_action :publish, method: :put do
    if resource.update(published: true)
      notice = t('admin.seo_filters.published')
      flash[:warning] = t('admin.seo_filters.published_empty') if Seo::Filters::Goods.call(resource).none?
      redirect_to resource_path(resource), notice:
    else
      redirect_to resource_path(resource), alert: resource.errors.full_messages.to_sentence
    end
  end

  member_action :unpublish, method: :put do
    resource.update!(published: false)
    redirect_to resource_path(resource), notice: t('admin.seo_filters.unpublished')
  end

  member_action :remove, method: %i[get put] do
    return render_remove_form(target: nil) if request.get?

    redirect = params[:outcome] == 'redirect'
    target = params[:target].to_s.strip
    return render_remove_form(target:, errors: { target: :blank }) if redirect && target.empty?

    result = Seo::Filters::Remove.call(filter: resource, target: (target if redirect))
    return redirect_to(resource_path(resource), notice: t('admin.seo_filters.removed')) if result.ok?

    render_remove_form(target: params[:target], errors: result.errors)
  end

  member_action :restore, method: :put do
    resource.restore!
    redirect_to resource_path(resource), notice: t('admin.seo_filters.restored')
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

    attr_reader :seo_preview

    helper_method :seo_preview

    # A removed filter keeps still until it is restored; a filter that is there has nothing to restore.
    rescue_from ActiveAdmin::AccessDenied do |denied|
      filter = denied.subject
      key = filter.is_a?(Seo::Filter) && filter.removed? ? 'removed_locked' : 'not_removed'
      path = filter.is_a?(Seo::Filter) ? resource_path(filter) : collection_path
      redirect_to path, alert: t("admin.seo_filters.#{key}")
    end

    def create
      return preview_goods(build_resource, :new) if params[:preview]

      super
    end

    def update
      if params[:preview]
        resource.assign_attributes(permitted_params[:seo_filter])
        return preview_goods(resource, :edit)
      end

      super
    end

    private

    # Shows what the filter would select without saving it; a wrong parameter is shown instead.
    def preview_goods(filter, view)
      filter.validate
      wrong = filter.errors.attribute_names.intersect?(%i[params recipe_scope])
      @seo_preview = Seo::Filters::Preview.call(filter) unless wrong
      render view, status: @seo_preview ? :ok : :unprocessable_content
    end

    def render_remove_form(target:, errors: {})
      @page_title = t('admin.seo_filters.remove_title', name: resource.name_uk)
      render 'admin/seo/filter_remove', locals: { target:, errors: }, status: errors.any? ? :unprocessable_content : :ok
    end
  end
end
