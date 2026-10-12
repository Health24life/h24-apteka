# frozen_string_literal: true

Mobility.configure do
  plugins do
    backend :jsonb
    active_record
    reader
    writer
    backend_reader
    query
    cache
    dirty
    presence
    locale_accessors
    fallbacks
  end
end
