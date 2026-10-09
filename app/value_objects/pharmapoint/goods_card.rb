# frozen_string_literal: true

# The static card of a release form.
class Pharmapoint::GoodsCard < Data.define(:release_form, :dosage, :mnn, :composition, :instruction_html,
                                           :image_paths, :is_recipe, :is_strict_recipe, :in_medication_program)
end
