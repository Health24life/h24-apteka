# frozen_string_literal: true

# What every reader needs. The partner's contract is unstable: a key may be missing, hold null, an empty array in
# place of an object or a number in place of a string, so each value is normalized here and absence is not an error.
module Pharmapoint::Readers::Base
  module_function

  def envelope(body, key = 'data')
    raise Pharmapoint::InvalidResponse, 'the answer is not a JSON object' unless body.is_a?(Hash)
    raise Pharmapoint::InvalidResponse, "the answer has no #{key}" unless body.key?(key)

    body[key]
  end

  def hash_or_empty(value) = value.is_a?(Hash) ? value : {}

  def list(value) = value.is_a?(Array) ? value : []

  def text(value)
    string = value.is_a?(String) || value.is_a?(Numeric) ? value.to_s.squish : ''
    string.presence
  end

  # Ids come as numbers, numeric strings or UUIDs and are kept as strings.
  def external_id(value) = value.is_a?(Hash) ? nil : text(value)

  def integer(value)
    case value
    when Integer then value
    when Float then value.to_i
    else Integer(value.to_s, exception: false)
    end
  end

  def float(value)
    case value
    when Float then value
    when Integer then value.to_f
    else Float(value.to_s, exception: false)
    end
  end

  def affirmative?(value) = value == true

  def images(value) = (value.is_a?(Array) ? value : [ value ]).filter_map { text(it) }

  # The Ukrainian name, or the main one: the Russian name field often holds Ukrainian text, so it is never used.
  def name(record) = text(record['name_uk']) || text(record['name'])

  # Reads the fields a mapping lists, `{ out_name => [source_key, type] }`, each converted to its type.
  def pick(record, fields)
    fields.to_h { |out, (key, type)| [ out, convert(type, record[key]) ] }
  end

  def convert(type, value)
    case type
    when 'id' then external_id(value)
    when 'int' then integer(value)
    when 'float' then float(value)
    when 'flag' then affirmative?(value)
    when 'images' then images(value)
    else text(value)
    end
  end
end
