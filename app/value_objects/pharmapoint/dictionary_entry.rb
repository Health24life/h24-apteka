# frozen_string_literal: true

# One entry of a dictionary: the provider's id and the Ukrainian name.
class Pharmapoint::DictionaryEntry < Data.define(:external_id, :name)
end
