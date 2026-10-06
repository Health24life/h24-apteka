# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::InstructionParser do
  def parse(html) = described_class.call(html)

  def anchors(html) = parse(html).sections.map(&:anchor)

  let(:spazmalgon) { Rails.root.join('spec/fixtures/instructions/spazmalgon.html').read }

  describe 'an instruction with sections' do
    subject(:result) { parse(spazmalgon) }

    it 'finds the known sections in document order' do
      expect(result.sections.map(&:code)).to eq(%w[sklad likarska-forma farmakoterapevtychna-hrupa pokazannia
                                                   sposib-zastosuvannia-ta-dozy termin-prydatnosti])
    end

    it 'numbers the sections from one' do
      expect(result.sections.map(&:position)).to eq((1..6).to_a)
    end

    it 'uses the code as the anchor of a section met once' do
      expect(result.sections.map(&:anchor)).to eq(result.sections.map(&:code))
    end

    it 'keeps no fallback text' do
      expect(result.fallback_html).to be_nil
    end

    it 'drops the heading part with the drug name before the first section' do
      expect(result.sections.map(&:body_html).join).not_to include('СПАЗМАЛГОН', 'ІНСТРУКЦІЯ')
    end

    it 'keeps the heading as written in the instruction' do
      expect(result.sections.first.source_title).to eq('Склад:')
    end

    it 'collects the paragraphs under a heading into its text' do
      expect(result.sections.first.body_html).to eq(
        '<p><i>діючі речовини: </i>метамізол натрію, пітофенону гідрохлорид, фенпіверинію бромід;</p>' \
        '<p><i>допоміжні речовини: </i>лактоза, моногідрат; крохмаль кукурудзяний.</p>'
      )
    end

    it 'turns the text after a heading in the same paragraph into the first paragraph of the section' do
      expect(result.sections.find { it.code == 'likarska-forma' }.body_html).to eq('<p>Таблетки.</p>')
    end

    it 'leaves a heading outside the list inside the current section' do
      dosage = result.sections.find { it.code == 'sposib-zastosuvannia-ta-dozy' }

      expect(dosage.body_html).to eq('<p>Дорослим — по 1–2 таблетки 2–3 рази на добу.</p>' \
                                     '<p><b>Діти.</b></p><p>Не застосовувати дітям віком до 15 років.</p>')
    end

    it 'gives the same result when the instruction is parsed again' do
      expect(parse(spazmalgon)).to eq(result)
    end
  end

  describe 'headings' do
    it 'gives a synonym, another case and other punctuation the same code and anchor', :aggregate_failures do
      section = parse('<p><b>СПОСІБ ЗАСТОСУВАННЯ:</b></p><p>По 1 таблетці.</p>' \
                      '<p><b>Показання</b></p><p>Біль.</p>').sections.first

      expect(section).to have_attributes(code: 'sposib-zastosuvannia-ta-dozy',
                                         anchor: 'sposib-zastosuvannia-ta-dozy',
                                         source_title: 'СПОСІБ ЗАСТОСУВАННЯ:')
    end

    it 'recognises a heading typed with Latin letters that look Cyrillic' do
      expect(anchors('<p><b>Лiкарська форма.</b> Таблетки.</p><p><b>Показання.</b></p><p>Біль.</p>'))
        .to eq(%w[likarska-forma pokazannia])
    end

    it 'drops the punctuation left outside the bold heading' do
      section = parse('<p><b>Склад</b>: вода.</p><p><b>Показання</b></p><p>Біль.</p>').sections.first

      expect(section.body_html).to eq('<p>вода.</p>')
    end

    it 'drops a non-breaking space and punctuation left outside the bold heading', :aggregate_failures do
      result = parse('<p><b>Склад</b>&nbsp;: вода.</p><p><b>Лікарська форма.</b>&nbsp;Таблетки.</p>')

      expect(result.sections.map(&:body_html)).to eq([ '<p>вода.</p>', '<p>Таблетки.</p>' ])
    end

    it 'does not take bold text inside a paragraph for a heading' do
      result = parse('<p><b>Склад.</b></p><p>Спазмалгон<b><sup>®</sup></b> містить метамізол.</p>' \
                     '<p><b>Показання.</b></p><p>Біль.</p>')

      expect(result.sections.first.body_html).to eq('<p>Спазмалгон<b><sup>®</sup></b> містить метамізол.</p>')
    end

    it 'gives a repeated section a numbered anchor' do
      expect(anchors('<p><b>Показання</b></p><p>Біль.</p><p><b>Показання</b></p><p>Спазм.</p>'))
        .to eq(%w[pokazannia pokazannia-2])
    end

    it 'skips a known heading with no text under it' do
      result = parse('<p><b>Склад.</b></p><p><b>Показання.</b></p><p>Біль.</p>' \
                     '<p><b>Протипоказання.</b></p><p>Вагітність.</p>')

      expect(result.sections.map { [ it.position, it.anchor ] })
        .to eq([ [ 1, 'pokazannia' ], [ 2, 'protypokazannia' ] ])
    end

    it 'keeps text outside paragraphs inside the current section' do
      result = parse('<p><b>Показання</b></p><ul><li>Біль.</li></ul>Спазм.<p><b>Протипоказання</b></p><p>Ні.</p>')

      expect(result.sections.first.body_html).to eq('<ul><li>Біль.</li></ul>Спазм.')
    end
  end

  describe 'cleaning' do
    let(:dirty) do
      '<p onclick="steal()" style="color:red"><b>Показання</b></p>' \
        '<script>alert(1)</script><style>p{}</style>' \
        '<p><a href="https://example.com">Біль</a><img src="x.png"><span>, спазм.</span></p>' \
        '<p><b>Протипоказання</b></p><p>Ні.</p>'
    end

    it 'leaves no scripts, styles, attributes or tags outside the list in the text', :aggregate_failures do
      text = parse(dirty).sections.map(&:body_html).join

      expect(text).not_to include('script', 'alert', 'style', 'onclick', 'href', 'img', 'span')
      expect(text).to include('<p>Біль, спазм.</p>')
    end

    it 'cleans the fallback text the same way' do
      fallback = parse('<p onclick="x">Вітамін C.</p><script>alert(1)</script>').fallback_html

      expect(fallback).to eq('<p>Вітамін C.</p>')
    end
  end

  describe 'an instruction that is not split' do
    it 'keeps an instruction without headings as fallback text', :aggregate_failures do
      result = parse('<p>Харчова добавка.</p><p>Приймати під час їжі.</p>')

      expect(result.sections).to eq([])
      expect(result.fallback_html).to eq('<p>Харчова добавка.</p><p>Приймати під час їжі.</p>')
    end

    it 'keeps an instruction with a single recognised section as fallback text', :aggregate_failures do
      result = parse('<p><b>Склад:</b> вітамін C.</p><p>Приймати під час їжі.</p>')

      expect(result.sections).to eq([])
      expect(result.fallback_html).to eq('<p><b>Склад:</b> вітамін C.</p><p>Приймати під час їжі.</p>')
    end
  end

  describe 'no instruction' do
    it 'returns an empty result for a missing, empty or blank instruction' do
      [ nil, '', '   ', '<p>&nbsp;</p>', '<script>alert(1)</script>' ].each do |html|
        expect(parse(html)).to eq(Catalog::ParsedInstruction.empty), html.inspect
      end
    end
  end
end
