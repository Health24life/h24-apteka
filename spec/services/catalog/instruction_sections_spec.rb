# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::InstructionSections do
  let(:nothing_taken) do
    Class.new do
      def where(*) = self
      def pluck(_column) = []
    end.new
  end

  it 'lists the twelve sections in the order of the list' do
    expected = %w[sklad likarska-forma farmakoterapevtychna-hrupa pokazannia protypokazannia
                  vzaiemodiia-z-inshymy-likarskymy-zasobamy sposib-zastosuvannia-ta-dozy pobichni-reaktsii
                  peredozuvannia umovy-zberihannia termin-prydatnosti katehoriia-vidpusku]

    expect(described_class::CODES).to eq(expected)
  end

  it 'fixes each code as the transliteration of its Ukrainian heading' do
    described_class::CODES.each do |code|
      heading = I18n.t(code, scope: 'catalog.instruction_sections', locale: :uk)

      expect(Catalog::SlugGenerator.call(heading, scope: nothing_taken)).to eq(code)
    end
  end

  it 'has a heading for every code in every interface language' do
    missing = described_class::CODES.product(I18n.available_locales).reject do |code, locale|
      I18n.exists?("catalog.instruction_sections.#{code}", locale, fallback: false)
    end

    expect(missing).to eq([])
  end

  it 'recognises the Ukrainian heading of every section' do
    described_class::CODES.each do |code|
      heading = I18n.t(code, scope: 'catalog.instruction_sections', locale: :uk)

      expect(described_class.code_for(heading)).to eq(code)
    end
  end

  it 'gives every synonym to one section only' do
    synonyms = described_class::ALL.flat_map(&:synonyms)

    expect(synonyms).to eq(synonyms.uniq)
  end

  it 'keeps synonyms in their normalised form' do
    described_class::ALL.flat_map(&:synonyms).each do |synonym|
      expect(described_class.normalize(synonym)).to eq(synonym)
    end
  end

  it 'ignores case, extra spaces and the trailing punctuation of a heading' do
    expect(described_class.code_for("  СПОСІБ\u00A0 ЗАСТОСУВАННЯ: ")).to eq('sposib-zastosuvannia-ta-dozy')
  end

  it 'recognises a heading typed with Latin letters that look Cyrillic' do
    expect(described_class.code_for('Лiкарська форма.')).to eq('likarska-forma')
  end

  it 'does not recognise a heading outside the list' do
    expect(described_class.code_for('Діти')).to be_nil
  end
end
