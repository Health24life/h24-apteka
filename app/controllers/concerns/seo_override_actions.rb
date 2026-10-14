# frozen_string_literal: true

# The form of the SEO data an editor sets by hand on the card of a page: title, description, H1, indexing and SEO
# text. A filled field wins over the template and an emptied one gives the page back to it. Long texts are kept but
# named, as the endpoint returns them uncut; a cleaned SEO text is named too.
module SeoOverrideActions
  PERMITTED = %i[title_uk description_uk h1_uk robots seo_text_uk].freeze

  def change_seo_override
    override = resource.seo_override || resource.build_seo_override
    return render_seo_override_form(override) if request.get?

    override.assign_attributes(params.expect(seo_override: PERMITTED))
    override.save ? saved_seo_override(override) : render_seo_override_form(override, status: :unprocessable_content)
  end

  private

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
    @page_title = t('admin.seo_override.form_title', name: helpers.seo_record_name(resource))
    render 'admin/seo/override', locals: { override: }, status:
  end
end
