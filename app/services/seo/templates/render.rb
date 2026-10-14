# frozen_string_literal: true

# Fills the placeholders of a template text and tidies up after the empty ones: no placeholder, double space, empty
# brackets or dangling separator is left behind.
class Seo::Templates::Render
  SEPARATOR = '[,;:]|[—–]'

  def self.call(text, values)
    filled = text.gsub(Seo::Template::PLACEHOLDER) { values[::Regexp.last_match(1)].to_s.strip }
    tidy(filled)
  end

  def self.tidy(text)
    text.gsub(/\(\s*\)|\[\s*\]/, '')
        .gsub(/\s+/, ' ')
        .gsub(/ ([,;:.!?)\]])/, '\1')
        .gsub(/(#{SEPARATOR})(?:\s*(?:#{SEPARATOR}))+/o, '\1')
        .sub(/\A(?:\s|#{SEPARATOR})+/o, '')
        .sub(/(?:\s|#{SEPARATOR})+\z/o, '')
  end

  private_class_method :tidy
end
