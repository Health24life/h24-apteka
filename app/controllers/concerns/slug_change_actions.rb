# frozen_string_literal: true

# The change of the slug of a page in two steps: the first checks the new slug and shows the new address with a
# warning about the redirect, the second, sent from that page, saves it.
module SlugChangeActions
  def change_slug
    return render_slug_form(resource.slug) if request.get?

    slug = params.require(:slug)
    result = changed_slug(slug)
    return redirect_to(resource_path(resource), notice: t("admin.slug.#{result.status}")) if finished?(result)

    render_slug_form(slug, result:, status: result.ok? ? :ok : :unprocessable_content)
  end

  private

  # The second step saves; the first only checks.
  def changed_slug(slug)
    changer = Catalog::Slugs::Changer
    params[:confirmed] ? changer.call(record: resource, slug:) : changer.check(record: resource, slug:)
  end

  def finished?(result) = %i[changed unchanged].include?(result.status)

  def render_slug_form(slug, result: nil, status: :ok)
    @page_title = t('admin.slug.form_title', name: helpers.seo_record_name(resource))
    render 'admin/seo/slug', locals: { slug:, result:, url: new_url(slug, result) }, status:
  end

  # The full address the page would have, shown once the new slug passed the check.
  def new_url(slug, result)
    return unless result&.status == :valid

    paths = Seo::Pages::Path.new
    copy = resource.dup.tap { it.slug = slug.strip }
    paths.url(paths.record(copy).to_s)
  end
end
