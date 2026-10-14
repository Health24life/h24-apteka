# frozen_string_literal: true

# Shortens a generated text to the limit at a word boundary, ending it with an ellipsis that counts toward the limit.
class Seo::Templates::Truncate
  ELLIPSIS = '…'

  def self.call(text, limit)
    return text if text.length <= limit

    cut = text[0, limit - ELLIPSIS.length].to_s
    boundary = cut.rindex(' ')
    cut = cut[0, boundary].to_s if boundary&.positive?
    "#{cut.sub(/(?:\s|#{Seo::Templates::Render::SEPARATOR})+\z/o, '')}#{ELLIPSIS}"
  end
end
