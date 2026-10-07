# frozen_string_literal: true

# The twelve instruction sections a product card can navigate to. A code is the KMU-55 transliteration of the
# Ukrainian heading and doubles as the anchor, so it is fixed here as a literal: published links depend on it.
# Headings shown to people live in the locale files under catalog.instruction_sections.
module Catalog::Instructions::Sections
  Section = Data.define(:code, :synonyms)

  ALL = [
    Section.new(code: 'sklad', synonyms: [ 'склад', 'склад лікарського засобу', 'склад препарату' ]),
    Section.new(code: 'likarska-forma', synonyms: [ 'лікарська форма' ]),
    Section.new(code: 'farmakoterapevtychna-hrupa', synonyms: [ 'фармакотерапевтична група' ]),
    Section.new(code: 'pokazannia',
                synonyms: [ 'показання', 'показання до застосування', 'показання для застосування' ]),
    Section.new(code: 'protypokazannia', synonyms: [ 'протипоказання' ]),
    Section.new(code: 'vzaiemodiia-z-inshymy-likarskymy-zasobamy',
                synonyms: [ 'взаємодія з іншими лікарськими засобами',
                            'взаємодія з іншими лікарськими засобами та інші види взаємодій',
                            'взаємодія з іншими лікарськими засобами та інші форми взаємодій' ]),
    Section.new(code: 'sposib-zastosuvannia-ta-dozy',
                synonyms: [ 'спосіб застосування та дози', 'спосіб застосування і дози', 'спосіб застосування' ]),
    Section.new(code: 'pobichni-reaktsii', synonyms: [ 'побічні реакції', 'побічна дія', 'побічні дії' ]),
    Section.new(code: 'peredozuvannia', synonyms: [ 'передозування' ]),
    Section.new(code: 'umovy-zberihannia', synonyms: [ 'умови зберігання' ]),
    Section.new(code: 'termin-prydatnosti', synonyms: [ 'термін придатності' ]),
    Section.new(code: 'katehoriia-vidpusku', synonyms: [ 'категорія відпуску' ])
  ].freeze

  CODES = ALL.map(&:code).freeze
  CODE_BY_SYNONYM = ALL.flat_map { |section| section.synonyms.map { [ it, section.code ] } }.to_h.freeze

  # Latin letters that look Cyrillic slip into Ukrainian texts typed on a mixed keyboard. The two strings look alike
  # on purpose: the first is ASCII, the second is Cyrillic, letter for letter.
  LATIN_LOOKALIKES = 'aceiopxyABCEHIKMOPTXY'
  CYRILLIC_LETTERS = 'асеіорхуАВСЕНІКМОРТХУ'

  def self.code_for(heading) = CODE_BY_SYNONYM[normalize(heading)]

  def self.normalize(heading) = heading.squish.tr(LATIN_LOOKALIKES, CYRILLIC_LETTERS).downcase.sub(/[\s.:]+\z/, '')
end
