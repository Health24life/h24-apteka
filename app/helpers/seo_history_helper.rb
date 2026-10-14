# frozen_string_literal: true

# The history of SEO data in the admin: who made a change, to what, and each field before and after it.
module SeoHistoryHelper
  # Bookkeeping columns a version records but an editor never set.
  BOOKKEEPING = %w[id created_at updated_at locale translated_model_id seo_override_id seo_static_page_id target_type
                   target_id key].freeze
  SHOWN_LENGTH = 160

  def seo_version_author(version) = version.author.try(:email) || t('admin.seo_history.system')

  def seo_version_object(version)
    name = version.item_type.safe_constantize&.model_name&.human || version.item_type
    "#{name}: #{t(version.event, scope: 'admin.seo_history.events')}"
  end

  # Each field a version changed with its value before and after, as an editor reads them.
  def seo_version_changes(version)
    model = version.item_type.safe_constantize
    changes = version.object_changes.to_h.except(*BOOKKEEPING)
    changes.except(*seo_language_copies(changes)).map do |field, (before, after)|
      [ model&.human_attribute_name(field) || field, seo_value(before), seo_value(after) ]
    end
  end

  # A translated field changes twice in a version: as its column of languages and as the accessor of one language,
  # such as `description` and `description_uk`. Only the column is shown.
  def seo_language_copies(changes)
    suffix = /_(?:#{I18n.available_locales.join('|')})\z/
    changes.keys.select { it.match?(suffix) && changes.key?(it.sub(suffix, '')) }
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
