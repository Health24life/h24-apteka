# frozen_string_literal: true

# HTML attributes cleaned of what the front does not show before every validation, in each language of the site, so
# no way of saving lets a script or a stray tag reach the API.
module Seo::SanitizedHtml
  extend ActiveSupport::Concern

  included do
    class_attribute :sanitized_html_attributes, instance_writer: false, default: []
    before_validation :sanitize_html
  end

  module ClassMethods
    def sanitized_html(*attributes)
      self.sanitized_html_attributes += attributes
    end
  end

  # Whether the last validation took something out of a text, so the admin can say the text changed.
  def html_sanitized? = @html_sanitized == true

  private

  def sanitize_html
    @html_sanitized = false
    sanitized_html_attributes.product(Rails.configuration.x.catalog_locales).each do |attribute, locale|
      accessor = "#{attribute}_#{locale}"
      result = Seo::Texts::Sanitize.call(public_send(accessor))
      next unless result.changed

      public_send(:"#{accessor}=", result.html)
      @html_sanitized = true
    end
  end
end
