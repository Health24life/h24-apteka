# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Search::Adapters do
  let!(:pharmapoint) { create(:provider, code: 'pharmapoint') }

  def providers(**config) = described_class.build(config: search_config(**config)).map { it.provider.code }

  it 'searches an enabled provider the configuration allows' do
    expect(providers(providers: 'pharmapoint')).to eq(%w[pharmapoint])
  end

  it 'leaves out a provider the configuration does not list, though it stays enabled', :aggregate_failures do
    expect(providers(providers: '')).to be_empty
    expect(pharmapoint.reload.active).to be(true)
  end

  it 'leaves out a disabled provider' do
    pharmapoint.update!(active: false)

    expect(providers(providers: 'pharmapoint')).to be_empty
  end

  it 'leaves out a provider with no adapter, such as one of our own' do
    create(:provider, :own, code: 'own_stock')

    expect(providers(providers: 'pharmapoint, own_stock')).to eq(%w[pharmapoint])
  end
end
