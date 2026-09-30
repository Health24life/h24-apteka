# frozen_string_literal: true

# Transliterates Ukrainian text to a slug with the KMU-55 table. The gem defaults to DSTU 9112, which gives other slugs.
class Catalog::SlugGenerator
  FALLBACK = 'item'

  def self.call(text, scope:) = new(scope).call(text)

  def initialize(scope)
    @scope = scope
  end

  def call(text)
    base = transliterate(text)
    return base unless taken?(base)

    number = 2
    loop do
      candidate = with_suffix(base, "-#{number}")
      return candidate unless taken?(candidate)

      number += 1
    end
  end

  private

  def transliterate(text)
    slug = UkrainianLatin.new.encode(text.to_s, 'KMU_55').parameterize
    slug.first(Catalog::SLUG_MAX_LENGTH).delete_suffix('-').presence || FALLBACK
  end

  # Truncates the base so the whole slug, suffix included, still fits the limit.
  def with_suffix(base, suffix)
    "#{base.first(Catalog::SLUG_MAX_LENGTH - suffix.length).delete_suffix('-')}#{suffix}"
  end

  def taken?(slug)
    @scope.exists?(slug:)
  end
end
