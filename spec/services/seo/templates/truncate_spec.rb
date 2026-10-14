# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Templates::Truncate do
  it 'leaves a text within the limit as it is' do
    expect(described_class.call('Нурофен 200 мг', 70)).to eq('Нурофен 200 мг')
  end

  it 'cuts a longer text at a word boundary with an ellipsis within the limit', :aggregate_failures do
    text = 'Нурофен 200 мг таблетки вкриті оболонкою — інструкція із застосування, склад, показання'
    cut = described_class.call(text, 70)

    expect(cut.length).to be <= 70
    expect(cut).to end_with('інструкція із…')
  end

  it 'leaves no separator before the ellipsis' do
    expect(described_class.call('Нурофен — інструкція, склад, показання', 30)).to eq('Нурофен — інструкція, склад…')
  end

  it 'cuts inside a word that has no boundary within the limit' do
    expect(described_class.call('а' * 100, 10)).to eq("#{'а' * 9}…")
  end
end
