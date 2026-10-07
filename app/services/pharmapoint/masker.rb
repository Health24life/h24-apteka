# frozen_string_literal: true

# Hides what must not reach the request log (the key, a client's phone) and makes every string safe for jsonb.
class Pharmapoint::Masker
  MARKER = '[masked]'

  def initialize(config: Pharmapoint::Config.current)
    @config = config
  end

  def headers(raw)
    raw.to_h { |name, value| [ name.to_s.downcase, secret_header?(name) ? MARKER : value.to_s ] }
  end

  def body(value)
    case value
    when Hash then value.to_h { |key, item| [ key.to_s, secret_key?(key) ? MARKER : body(item) ] }
    when Array then value.map { body(it) }
    when String then clean(value)
    else value
    end
  end

  # Free text such as an error message: the key is cut out wherever it happens to appear.
  def text(value)
    api_key = @config.api_key
    clean(api_key.present? ? value.gsub(api_key, MARKER) : value)
  end

  private

  def secret_header?(name) = Pharmapoint::Config::SECRET_HEADERS.include?(name.to_s.downcase)

  def secret_key?(key) = Pharmapoint::Config::SECRET_BODY_KEYS.include?(key.to_s.downcase)

  # jsonb refuses invalid UTF-8 and the NUL character.
  def clean(string) = string.dup.force_encoding(Encoding::UTF_8).scrub.delete("\u0000")
end
