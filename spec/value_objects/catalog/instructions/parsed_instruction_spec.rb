# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Instructions::ParsedInstruction do
  it 'has neither sections nor fallback text when empty', :aggregate_failures do
    empty = described_class.empty

    expect(empty.sections).to eq([])
    expect(empty.fallback_html).to be_nil
    expect(empty).not_to be_parsed
  end

  it 'counts as parsed when it has sections' do
    section = described_class::Section.new(position: 1, code: 'sklad', anchor: 'sklad', source_title: 'Склад',
                                           body_html: '<p>Вода.</p>')

    expect(described_class.new(sections: [ section ], fallback_html: nil)).to be_parsed
  end
end
