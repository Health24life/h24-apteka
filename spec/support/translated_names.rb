# frozen_string_literal: true

module TranslatedNames
  def translation_class(model) = model.const_defined?(:Translation, false) ? model.const_get(:Translation, false) : nil

  def translation_foreign_key(model) = translation_class(model).reflect_on_association(:translated_model).foreign_key

  def stored_names(record)
    model = record.class
    if (translation = translation_class(model))
      translation.where(translation_foreign_key(model) => record.id).pluck(:locale, :name).to_h
    else
      model.where(id: record.id).pick(:name)
    end
  end
end
