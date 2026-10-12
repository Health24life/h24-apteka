# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Readers::Dictionaries do
  let(:result) { described_class.call(JSON.parse(pharmapoint_fixture('dictionaries'))) }

  it 'reads the six dictionaries with the Ukrainian names', :aggregate_failures do
    expect(result.forms).to include(Pharmapoint::DictionaryEntry.new(external_id: '223', name: 'Таблетки'))
    expect(result.measures).to include(Pharmapoint::DictionaryEntry.new(external_id: '5', name: '%'))
    expect(result.brands).to include(Pharmapoint::DictionaryEntry.new(external_id: '57', name: 'Подорожник'))
  end

  it 'reads every dictionary the answer has' do
    expect(result.to_h.values).to all(be_present)
  end

  it 'skips the flat category list, which has no parents' do
    expect(result.as_json.to_s).not_to include('Песарії')
  end

  it 'gives an empty list for a dictionary the answer does not have' do
    expect(described_class.call({ 'data' => {} }).forms).to eq([])
  end
end
