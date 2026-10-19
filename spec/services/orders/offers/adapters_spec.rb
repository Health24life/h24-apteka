# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Offers::Adapters do
  it 'gives the adapter of the provider by its code' do
    provider = create(:provider, code: 'pharmapoint')

    expect(described_class.for(provider)).to be_a(Pharmapoint::Offers).and(have_attributes(provider:))
  end

  it 'gives none for a provider without an adapter' do
    expect(described_class.for(create(:provider, code: 'own'))).to be_nil
  end
end
