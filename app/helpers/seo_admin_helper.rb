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
    url = seo_front_url(record) or return
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

  def seo_placeholders_hint(template)
    placeholders = template.placeholders.map { "{#{it}}" }
    return t('admin.seo_templates.no_placeholders') if placeholders.empty?

    t('admin.seo_templates.placeholders', list: placeholders.join(', '))
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
