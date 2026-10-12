# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Templates::Render do
  let(:values) { { 'name' => 'Нурофен', 'dosage' => '200 мг', 'producer' => 'Reckitt', 'inn' => nil } }

  def render(text) = described_class.call(text, values)

  it 'fills the placeholders with the values' do
    expect(render('{name} {dosage} — інструкція, {producer}')).to eq('Нурофен 200 мг — інструкція, Reckitt')
  end

  it 'leaves no trace of an empty value', :aggregate_failures do
    expect(render('{name}, {inn}, {producer}')).to eq('Нурофен, Reckitt')
    expect(render('{name} ({inn}) — інструкція')).to eq('Нурофен — інструкція')
    expect(render('{name} — {inn} — інструкція')).to eq('Нурофен — інструкція')
    expect(render('{inn} {name}: інструкція, {inn}')).to eq('Нурофен: інструкція')
  end

  it 'keeps the hyphens that are part of a value' do
    expect(described_class.call('{name}', { 'name' => 'Анаферон дитячий 3-в-1' })).to eq('Анаферон дитячий 3-в-1')
  end
end
