# frozen_string_literal: true

# Meta tags of medicines stay neutral: no call to buy and no talk of price. The words are
# `neutral_wording_validator.forbidden_words` of the Ukrainian locale.
class NeutralWordingValidator < ActiveModel::EachValidator
  WORD = /[\p{L}'’ʼ]+/

  def validate_each(record, attribute, value)
    return if value.blank?

    found = value.to_s.downcase.scan(WORD) & forbidden_words
    record.errors.add(attribute, :not_neutral, words: found.join(', ')) if found.any?
  end

  private

  def forbidden_words = Array(I18n.t('neutral_wording_validator.forbidden_words', locale: :uk))
end
