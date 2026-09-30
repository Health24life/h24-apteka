# frozen_string_literal: true

# annotaterb merges every column of the globalize translation table into the base model's annotation and only drops
# the foreign key named after the demodulized class, so namespaced models leak `<namespace>_<model>_id`, `locale`
# and timestamps into the block. Only the translated attributes are real attributes of the model.
module AnnotateRb
  module ModelAnnotator
    module KeepTranslatedAttributesOnly
      def translated_columns
        return [] unless @klass.respond_to?(:translated_attribute_names)

        names = @klass.translated_attribute_names.map(&:to_s)
        super.select { names.include?(it.name) }
      end
    end

    ModelWrapper.prepend(KeepTranslatedAttributesOnly)
  end
end
