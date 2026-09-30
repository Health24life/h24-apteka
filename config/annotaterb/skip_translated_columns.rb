# frozen_string_literal: true

# annotaterb merges the globalize translation table columns into the base model's annotation and only drops the
# foreign key named after the demodulized class, so namespaced models leak `<namespace>_<model>_id` and the
# translated attributes into the block. Annotations must describe the model's own table only.
module AnnotateRb
  module ModelAnnotator
    module SkipTranslatedColumns
      def translated_columns = []
    end

    ModelWrapper.prepend(SkipTranslatedColumns)
  end
end
