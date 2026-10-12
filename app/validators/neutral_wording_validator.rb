# frozen_string_literal: true

# Meta tags of medicines stay neutral: no call to buy and no talk of price. The words come from the SEO settings.
class NeutralWordingValidator < ActiveModel::EachValidator
  WORD = /[\p{L}'’ʼ]+/

  def validate_each(record, attribute, value)
    return if value.blank?

    found = value.to_s.downcase.scan(WORD) & Seo::Config.current.forbidden_words
    record.errors.add(attribute, :not_neutral, words: found.join(', ')) if found.any?
  end
end
