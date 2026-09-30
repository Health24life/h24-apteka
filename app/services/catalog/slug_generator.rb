# frozen_string_literal: true

# Transliterates Ukrainian text to a slug with the KMU-55 table. The gem defaults to DSTU 9112, which gives other slugs.
class Catalog::SlugGenerator
  FALLBACK = 'item'
  BATCH = 50
  # The KMU table knows only Ukrainian letters and two apostrophe forms; anything else would reach parameterize,
  # which turns it into a hyphen or drops it.
  NON_KMU_LETTERS = 'ʼ‘`´ЫыЭэЁёЪъ'
  KMU_LETTERS = '’’’’ИиЕеЕе’’'

  def self.call(text, scope:) = new(scope).call(text)

  def initialize(scope)
    @scope = scope
  end

  def call(text)
    base = transliterate(text)
    first = 1
    loop do
      candidates = (first...(first + BATCH)).map { it == 1 ? base : with_suffix(base, "-#{it}") }
      taken = @scope.where(slug: candidates).pluck(:slug)
      free = candidates.find { taken.exclude?(it) }
      return free if free

      first += BATCH
    end
  end

  private

  def transliterate(text)
    kmu_text = text.to_s.tr(NON_KMU_LETTERS, KMU_LETTERS)
    slug = UkrainianLatin.new.encode(kmu_text, 'KMU_55').tr('_', '-').parameterize.squeeze('-')
    slug.first(Catalog::SLUG_MAX_LENGTH).delete_suffix('-').presence || FALLBACK
  end

  # Truncates the base so the whole slug, suffix included, still fits the limit.
  def with_suffix(base, suffix)
    "#{base.first(Catalog::SLUG_MAX_LENGTH - suffix.length).delete_suffix('-')}#{suffix}"
  end
end
