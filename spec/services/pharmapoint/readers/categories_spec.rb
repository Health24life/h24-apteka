# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::Categories do
  let(:tree) { described_class.call(JSON.parse(pharmapoint_fixture('category_tree'))) }

  it 'reads the roots and nests the children on four levels', :aggregate_failures do
    leaf = tree.first[:children].first[:children].first[:children].first

    expect(tree.pluck(:external_id)).to eq(%w[950 953])
    expect(leaf).to eq({ external_id: '980', name: 'Інші анальгетики й антипіретики', children: [] })
  end

  it 'refuses an answer that is not a tree' do
    expect { described_class.call('oops') }.to raise_error(Pharmapoint::InvalidResponse)
  end
end
