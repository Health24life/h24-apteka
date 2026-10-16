# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Search::Ref do
  it 'gives an opaque key of 16 hex digits that holds none of its parts', :aggregate_failures do
    ref = described_class.for('pharmapoint', 'a060d7776d3d256af22378e018bea336', '1795034')

    expect(ref).to match(/\A\h{16}\z/)
    expect(ref).not_to include('pharmapoint', '1795034')
  end

  it 'gives the same parts the same key' do
    first = described_class.for('pharmapoint', 'group', 'sku')

    expect(described_class.for('pharmapoint', 'group', 'sku')).to eq(first)
  end

  it 'tells the same ids of two providers apart' do
    expect(described_class.for('pharmapoint', 'group', 'sku')).not_to eq(described_class.for('other', 'group', 'sku'))
  end
end
