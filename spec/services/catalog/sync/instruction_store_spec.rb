# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::InstructionStore do
  let(:goods) { create(:catalog_goods) }
  let(:html) { '<p><b>Склад: </b>діюча речовина</p><p><b>Показання. </b>Біль.</p>' }

  def sections = goods.reload.instruction_sections

  it 'keeps the sections with their anchors and the source text', :aggregate_failures do
    described_class.call(goods, html)

    expect(sections.pluck(:code, :anchor)).to eq([ %w[sklad sklad], %w[pokazannia pokazannia] ])
    expect(goods.instruction_source_html).to eq(html)
  end

  it 'does not parse an instruction that has not changed', :aggregate_failures do
    described_class.call(goods, html)
    allow(Catalog::Instructions::Parser).to receive(:call).and_call_original

    described_class.call(goods.reload, html)

    expect(Catalog::Instructions::Parser).not_to have_received(:call)
    expect(sections.pluck(:anchor)).to eq(%w[sklad pokazannia])
  end

  it 'rebuilds the sections when the text changed and keeps the anchors of those that stayed', :aggregate_failures do
    described_class.call(goods, html)
    described_class.call(goods.reload, "#{html}<p><b>Протипоказання. </b>Нічого.</p>")

    expect(sections.pluck(:anchor)).to eq(%w[sklad pokazannia protypokazannia])
    expect(sections.pluck(:position)).to eq([ 1, 2, 3 ])
  end

  it 'drops a section that left the text' do
    described_class.call(goods, html)
    described_class.call(goods.reload, '<p><b>Склад: </b>а</p><p><b>Протипоказання. </b>б</p>')

    expect(sections.pluck(:code)).to eq(%w[sklad protypokazannia])
  end

  it 'keeps an instruction it cannot split as one block with no sections', :aggregate_failures do
    described_class.call(goods, '<p>Просто абзац без заголовків</p>')

    expect(sections).to be_empty
    expect(goods.instruction_html_uk).to include('Просто абзац')
  end

  it 'throws the unsplit block away once the instruction can be split', :aggregate_failures do
    described_class.call(goods, '<p>Просто абзац</p>')
    described_class.call(goods.reload, html)

    expect(goods.reload.instruction_html_uk).to be_nil
    expect(sections.size).to eq(2)
  end

  it 'drops scripts and event handlers from what is kept' do
    described_class.call(goods,
                         '<p onclick="x()"><b>Склад: </b>а<script>alert(1)</script></p><p><b>Показання. </b>б</p>')

    expect(sections.map(&:body_html_uk).join).not_to match(/script|onclick|alert/)
  end

  it 'saves an empty instruction as no instruction', :aggregate_failures do
    described_class.call(goods, html)
    described_class.call(goods.reload, '')

    expect(sections).to be_empty
    expect(goods.instruction_source_html).to be_nil
  end
end
