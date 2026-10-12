# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Drugstore::Brand do
  subject(:brand) { build(:catalog_drugstore_brand) }

  it { is_expected.to be_valid }
  it { is_expected.to validate_presence_of(:name) }

  describe '.find_linked' do
    it 'finds the record by provider and external id, treating the id as a string' do
      link = create(:provider_link, external_id: '42')

      expect(described_class.find_linked(link.provider, 42)).to eq(link.linkable)
    end

    it 'finds nothing for another provider' do
      link = create(:provider_link, external_id: '42')

      expect(described_class.find_linked(create(:provider), link.external_id)).to be_nil
    end
  end

  describe '#provider_ref' do
    it 'returns the external id at the given provider, or nil', :aggregate_failures do
      link = create(:provider_link, external_id: 'abc')

      expect(link.linkable.provider_ref(link.provider)).to eq('abc')
      expect(link.linkable.provider_ref(create(:provider))).to be_nil
    end
  end

  it 'refuses to delete a record that has a provider link' do
    link = create(:provider_link)

    expect { link.linkable.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end

# == Schema Information
#
# Table name: catalog_drugstore_brands
#
#  id         :bigint           not null, primary key
#  image_path :string
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
