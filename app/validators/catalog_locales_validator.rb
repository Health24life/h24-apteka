# frozen_string_literal: true

# Only this validation keeps translations in the catalog locales: the database does not check them. Mobility's dirty
# tracking keys a translated change as "<attribute>_<locale>" whichever backend stores it.
class CatalogLocalesValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, _value)
    prefix = "#{attribute}_"
    record.changes.each_key do |key|
      next unless key.start_with?(prefix)

      locale = key.delete_prefix(prefix)
      record.errors.add(attribute, :not_a_catalog_locale, language: locale) unless catalog_locale?(locale)
    end
  end

  private

  def catalog_locale?(locale) = Rails.configuration.x.catalog_locales.map(&:to_s).include?(locale)
end
