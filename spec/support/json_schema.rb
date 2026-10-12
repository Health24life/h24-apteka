# frozen_string_literal: true

# json-schema 6.2 still passes `quirks_mode:` to JSON.parse, which json 3 refuses, so every rswag check of a response
# schema fails before it compares anything. Remove this once json-schema stops passing the option.
JSON::Validator.singleton_class.prepend(
  Module.new do
    def parse(source)
      JSON.parse(source)
    rescue JSON::ParserError => e
      raise JSON::Schema::JsonParseError, e.message
    end
  end
)
