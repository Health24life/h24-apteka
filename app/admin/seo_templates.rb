# frozen_string_literal: true

ActiveAdmin.register Seo::Template, as: 'SeoTemplate' do
  menu parent: 'SEO', priority: 2

  config.batch_actions = false
  config.sort_order = 'page_type_asc'

  includes :category

  permit_params do
    texts = %i[title_uk description_uk h1_uk category_id is_recipe]
    action_name == 'create' ? texts + [ :page_type ] : texts
  end

  filter :page_type, as: :select, label: proc { Seo::Template.human_attribute_name(:page_type) },
                     collection: proc {
                       Seo::Template.page_types.keys.map { |type| [ I18n.t(type, scope: 'admin.seo_templates.page_types'), type ] }
                     }

  index do
    column(:page_type) { |template| link_to seo_page_type_label(template.page_type), resource_path(template) }
    column(:category) { |template| seo_branch_label(template) }
    column(:is_recipe) { |template| seo_recipe_label(template.is_recipe) }
    column :title_uk
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row(:page_type) { |template| seo_page_type_label(template.page_type) }
      row(:category) { |template| seo_branch_label(template) }
      row(:is_recipe) { |template| seo_recipe_label(template.is_recipe) }
      row :title_uk
      row :description_uk
      row :h1_uk
      row :updated_at
    end
    render 'admin/seo_history', record: resource
  end

  form do |f|
    template = f.object
    f.semantic_errors(*template.errors.attribute_names)
    f.inputs do
      if template.new_record?
        f.input :page_type, as: :select, include_blank: false,
                            collection: Seo::Template.page_types.keys.map { [ seo_page_type_label(it), it ] }
      end
      if template.new_record? || template.for_category? || template.for_goods?
        f.input :category, as: :tom_select, ajax: { resource: Catalog::Category }
      end
      if template.new_record? || template.for_goods?
        f.input :is_recipe, as: :select, include_blank: seo_recipe_label(nil),
                            collection: [ true, false ].map { [ seo_recipe_label(it), it ] }
      end
      para seo_placeholders_hint(template), class: 'inline-hints'
      f.input :title_uk
      f.input :description_uk, as: :text, input_html: { rows: 3 }
      f.input :h1_uk
    end

    # Fixed pages have no records to choose: their preview shows the texts as they are, with their length.
    model = Seo::Templates::Preview::MODELS[template.page_type.to_s]
    if model || seo_preview
      f.inputs t('admin.seo_templates.preview_title') do
        if model
          branch = { category_id: template.category_id, is_recipe: template.is_recipe }
          f.semantic_fields_for :preview, Struct.new(:record_id).new(seo_preview_record&.id) do |preview|
            preview.input :record_id, as: :tom_select, label: t('admin.seo_templates.preview_record'),
                                      hint: t('admin.seo_templates.preview_record_hint'),
                                      ajax: { resource: model, collection_name: :preview, params: branch }
          end
        end
        render 'admin/seo/template_preview', preview: seo_preview if seo_preview
      end
    end

    f.actions do
      f.action :submit
      f.action :submit, label: t('admin.seo_templates.preview'), button_html: { name: 'preview' }
      f.cancel_link
    end
  end

  controller do
    attr_reader :seo_preview, :seo_preview_record

    helper_method :seo_preview, :seo_preview_record

    # Only the general template of a page type is refused removal.
    rescue_from ActiveAdmin::AccessDenied do
      redirect_to collection_path, alert: t('admin.seo_templates.general_kept')
    end

    def create
      return preview_template(build_resource, :new) if params[:preview]

      super { |success, _failure| success.html { saved(resource) } }
    end

    def update
      if params[:preview]
        resource.assign_attributes(permitted_params[:seo_template])
        return preview_template(resource, :edit)
      end

      super { |success, _failure| success.html { saved(resource) } }
    end

    private

    def preview_template(template, view)
      template.validate
      @seo_preview_record = chosen_record(template)
      @seo_preview = Seo::Templates::Preview.call(template:, record: @seo_preview_record)
      flash.now[:error] = t('admin.seo_templates.not_applicable') if @seo_not_applicable
      render view
    end

    # Saved: says which texts the record chosen for the preview, or a fixed page, would see cut.
    def saved(template)
      record = chosen_record(template)
      fixed = !Seo::Templates::Preview::MODELS.key?(template.page_type.to_s)
      fields = cut_fields(Seo::Templates::Preview.call(template:, record:)) if record || fixed
      key = fixed ? 'saved_cut_page' : 'saved_cut'
      flash[:warning] = t(key, scope: 'admin.seo_templates', fields:) if fields.present?
      redirect_to resource_path(template)
    end

    def cut_fields(preview)
      cut = %i[title description].select { preview.public_send(it).cut? }
      cut.map { Seo::Template.human_attribute_name(it) }.join(', ')
    end

    def chosen_record(template)
      id = params.dig(:seo_template, :preview, :record_id).presence or return
      record = Seo::Templates::Preview::MODELS[template.page_type.to_s]&.find_by(id:)
      return record if Seo::Templates::Preview.applies_to?(template, record)

      @seo_not_applicable = true
      nil
    end
  end
end
