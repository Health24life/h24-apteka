# frozen_string_literal: true

# Transliterates Ukrainian text to a slug with the KMU-55 table. The gem defaults to DSTU 9112, which gives other slugs.
class Catalog::Slugs::Generator
  FALLBACK = 'item'
  BATCH = 50
  # The KMU table knows only Ukrainian letters and two apostrophe forms; anything else would reach parameterize,
  # which turns it into a hyphen or drops it.
  NON_KMU_LETTERS = 'ʼ‘`´ЫыЭэЁёЪъ'
  KMU_LETTERS = '’’’’ИиЕеЕе’’'

  # `reserved` holds the slugs a batch has handed out but not saved yet, which the scope cannot see. An old slug of the
  # scope's kind of page is taken as well, even past its period, until the cleanup removes the redirect.
  def self.call(text, scope:, reserved: Set.new) = new(scope, reserved:).call(text)

  def initialize(scope, reserved: Set.new)
    @scope = scope
    @reserved = reserved
  end

  def call(text)
    base = transliterate(text)
    first = 1
    loop do
      candidates = (first...(first + BATCH)).map { it == 1 ? base : with_suffix(base, "-#{it}") }
      taken = @scope.where(slug: candidates).pluck(:slug) + redirected(candidates)
      free = candidates.find { taken.exclude?(it) && @reserved.exclude?(it) }
      return free if free

      first += BATCH
    end
  end

  private

  # Records without pages of their own have no old slugs.
  def redirected(candidates)
    page_type = Seo::Redirect::PAGE_TYPES[@scope.polymorphic_name] or return []
    Seo::Redirect.where(page_type:, slug: candidates).pluck(:slug)
  end

  def transliterate(text)
    kmu_text = text.to_s.tr(NON_KMU_LETTERS, KMU_LETTERS)
    slug = UkrainianLatin.new.encode(kmu_text, 'KMU_55').tr('_', '-').parameterize.squeeze('-')
    slug.first(Catalog::Sluggable::MAX_LENGTH).delete_suffix('-').presence || FALLBACK
  end

  # Truncates the base so the whole slug, suffix included, still fits the limit.
  def with_suffix(base, suffix)
    "#{base.first(Catalog::Sluggable::MAX_LENGTH - suffix.length).delete_suffix('-')}#{suffix}"
  end
end
