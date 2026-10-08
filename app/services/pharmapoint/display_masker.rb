# frozen_string_literal: true

# Hides a client's personal data when a request log entry is shown, leaving the stored entry as it is. It works two
# ways at once: by the fields the partner's order contract puts the data in, and by what a value looks like wherever
# it stands, so a field nobody has listed yet does not leak a phone, an e-mail or a prescription number either.
class Pharmapoint::DisplayMasker
  MARKER = Pharmapoint::Masker::MARKER
  CUSTOMER_PREFIX = 'customer_'
  ANYWHERE = %w[recipe_number prescription_id repayment_code comment].freeze
  # Inside these objects every field is personal except the way of delivery; outside them the same names (the city or
  # street of a pharmacy) are not.
  WHOLE_OBJECTS = %w[delivery payment].freeze
  KEPT_INSIDE = %w[delivery_type_code].freeze
  INSIDE = { 'recipe' => %w[number] }.freeze
  PATTERNS = [
    /(?<!\d)\+?38[\s-]?\(?0\d{2}\)?[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2}(?!\d)/,
    /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/,
    # Four groups of four: a UUID or the partner's order number never splits that way.
    /\b[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}\b/
  ].freeze

  def self.body(value) = walk(value, nil)

  def self.query(value) = walk(value, nil)

  def self.headers(value) = value.to_h { |name, item| [ name, text(item) ] }

  def self.text(value) = PATTERNS.reduce(value) { |result, pattern| result.gsub(pattern, MARKER) }

  def self.walk(value, parent)
    case value
    when Hash then value.to_h { |key, item| [ key.to_s, mask_field(key.to_s, parent, item) ] }
    when Array then value.map { walk(it, parent) }
    when String then text(value)
    else value
    end
  end

  def self.mask_field(key, parent, value)
    return walk(value, key) unless personal?(key, parent)

    value.nil? ? nil : MARKER
  end

  def self.personal?(key, parent)
    return true if key.start_with?(CUSTOMER_PREFIX) || ANYWHERE.include?(key)
    return false unless parent
    return KEPT_INSIDE.exclude?(key) if WHOLE_OBJECTS.include?(parent)

    INSIDE[parent]&.include?(key) || false
  end

  private_class_method :walk, :mask_field, :personal?
end
