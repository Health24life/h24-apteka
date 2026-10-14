# frozen_string_literal: true

# Shared pieces of the SEO screens of the admin: the card and the front address of a page, and what a version changed.
module SeoAdminHelper
  # Bookkeeping columns a version records but an editor never set.
  BOOKKEEPING = %w[id created_at updated_at locale translated_model_id seo_override_id seo_static_page_id target_type
                   target_id key].freeze
  SHOWN_LENGTH = 160

  def seo_admin_path(record)
    case record
    when Catalog::Goods then admin_sku_path(record)
    when Catalog::Category then admin_category_path(record)
    when Seo::StaticPage then admin_static_page_path(record)
    when Seo::Template then admin_seo_template_path(record)
    when Seo::Redirect then admin_seo_redirect_path(record)
    end
  end

  def seo_front_url(record)
    paths = Seo::Pages::Path.new
    path = paths.record(record)
    path && paths.url(path)
  end

  def seo_front_link(record)
    path = Seo::Pages::Path.new.record(record) or return
    seo_front_path_link(path)
  end

  def seo_front_path_link(path)
    url = Seo::Pages::Path.new.url(path)
    link_to url, url, target: '_blank', rel: 'noopener'
  end

  def seo_api_link(record)
    path = Seo::Pages::Path.new.record(record) or return
    seo_api_path_link(path)
  end

  # The request the front makes for a page. The API answers on the admin's host.
  def seo_api_path_link(path)
    url = "#{api_v1_seo_page_path}?path=#{path}"
    link_to url, url, target: '_blank', rel: 'noopener'
  end

  # The old address of a redirect on the front.
  def seo_redirect_source(redirect)
    paths = Seo::Pages::Path.new
    case redirect.page_type
    when 'goods' then paths.goods(redirect.slug)
    when 'category' then paths.category(redirect.slug)
    else paths.static(redirect.slug)
    end
  end

  # A redirect acts while its old address leads where it points: it stops when a page is there again or, for an
  # editor's redirect, when its target left the storefront.
  def seo_redirect_active?(redirect)
    target = redirect.redirectable && Seo::Pages::Path.new.record(redirect.redirectable)
    !target.nil? && Seo::Pages::Resolve.call(seo_redirect_source(redirect)).location == target
  end

  def seo_redirect_expires_at(redirect) = redirect.created_at + Seo::Config.current.redirect_ttl

  def seo_redirect_kind(redirect) = t(redirect.manual ? 'manual' : 'auto', scope: 'admin.seo_redirects.kinds')

  def seo_redirect_target(redirect)
    path = seo_admin_path(redirect.redirectable)
    path ? link_to(seo_record_name(redirect.redirectable), path) : '—'
  end

  # A link to the template the page of a record takes its texts from, or nil while there is none.
  def seo_template_link(record)
    template = Seo::Pages::Meta.template_for(Seo::Pages::Resolve::Page.of(record))
    parts = [ seo_page_type_label(template.page_type) ]
    parts << seo_branch_label(template) if template.for_category? || template.for_goods?
    parts << seo_recipe_label(template.is_recipe) if template.for_goods?
    link_to parts.join(' · '), admin_seo_template_path(template)
  rescue Seo::Templates::Pick::Missing
    nil
  end

  # What the SEO endpoint answers for the page of a record now, or nil while its page type has no general template yet
  # (before the one-time task that adds them ran), so a card still opens.
  def seo_described(record)
    path = Seo::Pages::Path.new.record(record)
    path && Seo::Pages::Describe.call(path)
  rescue Seo::Templates::Pick::Missing
    nil
  end

  def seo_page_type_label(page_type) = t(page_type, scope: 'admin.seo_templates.page_types')

  def seo_branch_label(template) = template.category&.branch_name || t('admin.seo_templates.general')

  def seo_recipe_label(is_recipe) = t(is_recipe.nil? ? 'any' : is_recipe.to_s, scope: 'admin.seo_templates.recipe')

  # Each placeholder of the template's page type with what it gives on a page.
  def seo_placeholders(template)
    template.placeholders.map do |name|
      [ "{#{name}}", t(name, scope: [ :admin, :seo_templates, :placeholder_names, template.page_type ]) ]
    end
  end

  def seo_record_name(record)
    return '—' unless record

    record.try(:name_uk).presence || record.try(:title_uk).presence || "#{record.model_name.human} ##{record.id}"
  end

  def seo_version_author(version) = version.author.try(:email) || t('admin.seo_history.system')

  def seo_version_object(version)
    name = version.item_type.safe_constantize&.model_name&.human || version.item_type
    "#{name}: #{t(version.event, scope: 'admin.seo_history.events')}"
  end

  # Each field a version changed with its value before and after, as an editor reads them.
  def seo_version_changes(version)
    model = version.item_type.safe_constantize
    version.object_changes.to_h.except(*BOOKKEEPING).map do |field, (before, after)|
      [ model&.human_attribute_name(field) || field, seo_value(before), seo_value(after) ]
    end
  end

  def seo_value(value)
    value = value['uk'] if value.is_a?(Hash)
    return t(value.to_s, scope: 'admin.seo_history.booleans') if [ true, false ].include?(value)
    return t('admin.seo_history.empty_value') if value.blank?

    # Blocks of an HTML text end with a space, so their words do not run together once the tags are gone.
    text = strip_tags(value.to_s.gsub(%r{</(?:p|h2|h3|li|blockquote)>|<br\s*/?>}i, '\\0 ')).squish
    truncate(text, length: SHOWN_LENGTH)
  end
end
