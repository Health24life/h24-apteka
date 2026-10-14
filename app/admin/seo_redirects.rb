# frozen_string_literal: true

ActiveAdmin.register Seo::Redirect, as: 'SeoRedirect' do
  menu parent: 'SEO', priority: 3

  config.batch_actions = false
  config.sort_order = 'created_at_desc'

  includes :redirectable

  filter :manual, as: :select, label: proc { I18n.t('admin.seo_redirects.kind') },
                  collection: proc { I18n.t('admin.seo_redirects.kinds').values.zip([ true, false ]) }
  filter :slug_cont, as: :string, label: proc { I18n.t('admin.seo_redirects.source') }

  index do
    column(t('admin.seo_redirects.kind')) { |redirect| seo_redirect_kind(redirect) }
    column(t('admin.seo_redirects.source')) do |redirect|
      link_to seo_redirect_source(redirect), resource_path(redirect)
    end
    column(t('admin.seo_redirects.target')) { |redirect| seo_redirect_target(redirect) }
    column(t('admin.seo_redirects.target_url')) { |redirect| seo_front_url(redirect.redirectable) }
    column :created_at
    column(t('admin.seo_redirects.expires_at')) { |redirect| l(seo_redirect_expires_at(redirect), format: :long) }
    column(t('admin.seo_redirects.state')) do |redirect|
      next t('admin.seo_redirects.active') if seo_redirect_active?(redirect)

      status_tag('no', label: t('admin.seo_redirects.inactive'))
    end
    actions
  end

  show do
    attributes_table do
      row(t('admin.seo_redirects.kind')) { |redirect| seo_redirect_kind(redirect) }
      row(t('admin.seo_redirects.source')) { |redirect| seo_redirect_source(redirect) }
      row(t('admin.seo_redirects.target')) { |redirect| seo_redirect_target(redirect) }
      row(t('admin.seo_redirects.target_url')) { |redirect| seo_front_url(redirect.redirectable) }
      row :created_at
      row(t('admin.seo_redirects.expires_at')) { |redirect| l(seo_redirect_expires_at(redirect), format: :long) }
      row(t('admin.seo_redirects.state')) do |redirect|
        t(seo_redirect_active?(redirect) ? 'active' : 'inactive', scope: 'admin.seo_redirects')
      end
    end
    render 'admin/seo_history', record: resource, versions: Seo::Version.where(item: resource)
  end

  action_item :import, only: :index do
    link_to t('admin.seo_redirects.import'), url_for(action: :import), class: 'action-item-button'
  end

  collection_action :import, method: %i[get post] do
    return render('admin/seo/redirect_import', locals: { result: nil }) if request.get?

    result = Seo::Redirects::Import.call(params[:file]&.read, author: current_admin_user)
    return redirect_to(collection_path, notice: t('admin.seo_redirects.imported', count: result.created)) if result.ok?

    render 'admin/seo/redirect_import', locals: { result: }, status: :unprocessable_content
  end

  controller do
    def new = render_redirect_form(source: nil, target: nil)

    def create
      result = Seo::Redirects::Manual.call(source: params[:source], target: params[:target])
      return redirect_to(resource_path(result.redirect), notice: t('admin.seo_redirects.created')) if result.ok?

      render_redirect_form(source: params[:source], target: params[:target], errors: result.errors)
    end

    def edit = render_redirect_form(source: current_source, target: helpers.seo_front_url(resource.redirectable))

    def update
      result = Seo::Redirects::Manual.call(source: nil, target: params[:target], redirect: resource)
      return redirect_to(resource_path(resource), notice: t('admin.seo_redirects.updated')) if result.ok?

      render_redirect_form(source: current_source, target: params[:target], errors: result.errors)
    end

    private

    def current_source = helpers.seo_redirect_source(resource)

    def render_redirect_form(source:, target:, errors: {})
      @page_title = t(params[:id] ? 'admin.seo_redirects.edit_title' : 'admin.seo_redirects.new_title')
      render 'admin/seo/redirect_form', locals: { source:, target:, errors: },
                                        status: errors.any? ? :unprocessable_content : :ok
    end
  end
end
