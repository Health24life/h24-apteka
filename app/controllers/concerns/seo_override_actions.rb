# frozen_string_literal: true

# The form of the SEO data an editor sets by hand on the card of a page: title, description, H1, indexing and SEO
# text. A filled field wins over the template and an emptied one gives the page back to it. Long texts are kept but
# named, as the endpoint returns them uncut; a cleaned SEO text is named too.
#
# The form shows the template's text in a field nothing was set in. A text saved as the template gives it is not kept,
# so the page goes on following the template when the template or the record changes.
module SeoOverrideActions
  PERMITTED = %i[title_uk description_uk h1_uk robots seo_text_uk].freeze
  TEMPLATE_TEXTS = %i[title description h1].freeze

  def change_seo_override
    override = resource.seo_override || resource.build_seo_override
    return render_seo_override_form(override) if request.get?

    override.assign_attributes(params.expect(seo_override: PERMITTED))
    drop_template_texts(override)
    override.save ? saved_seo_override(override) : render_seo_override_form(override, status: :unprocessable_content)
  end

  private

  def drop_template_texts(override)
    generated = seo_template_texts or return
    TEMPLATE_TEXTS.each do |field|
      value = override.public_send(:"#{field}_uk")
      override.public_send(:"#{field}_uk=", nil) if value.to_s.strip == generated.public_send(field)
    end
  end

  def fill_template_texts(override)
    generated = seo_template_texts or return
    TEMPLATE_TEXTS.each do |field|
      override.public_send(:"#{field}_uk=", generated.public_send(field)) if override.public_send(:"#{field}_uk").blank?
    end
  end

  # Nil while the page type has no general template yet, so the form still opens.
  def seo_template_texts
    Seo::Pages::Meta.generated(Seo::Pages::Resolve::Page.of(resource))
  rescue Seo::Templates::Pick::Missing
    nil
  end

  def saved_seo_override(override)
    flash[:warning] = seo_override_warnings(override).join(' ').presence
    redirect_to resource_path(resource), notice: t('admin.seo_override.saved')
  end

  def seo_override_warnings(override)
    limits = { title: Seo::Pages::Meta::TITLE_LIMIT, description: Seo::Pages::Meta::DESCRIPTION_LIMIT }
    warnings = limits.filter_map do |field, limit|
      length = override.public_send(:"#{field}_uk").to_s.length
      t("admin.seo_override.#{field}_too_long", length:, limit:) if length > limit
    end
    override.html_sanitized? ? warnings << t('admin.seo_override.sanitized') : warnings
  end

  def render_seo_override_form(override, status: :ok)
    fill_template_texts(override)
    @page_title = t('admin.seo_override.form_title', name: helpers.seo_record_name(resource))
    render 'admin/seo/override', locals: { override: }, status:
  end
end
